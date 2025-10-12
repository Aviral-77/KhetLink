from groq import Groq
import os
import json
from typing import Dict, List, Any, Tuple
from pydantic import BaseModel
from dotenv import load_dotenv
load_dotenv()

class DiseaseAnalysis(BaseModel):
    infected_area_pct: float
    severity: str
    probable_diseases: List[str]

class ActionRecommendation(BaseModel):
    action: str
    priority: str
    timing: str

class FarmerResponse(BaseModel):
    answer: str
    actions: List[ActionRecommendation]
    confidence: float
    extracted_facts: DiseaseAnalysis
    language: str

class LLMService:
    def __init__(self):
        self.client = Groq(
            api_key=os.getenv("GROQ_API_KEY", "your-groq-api-key-here")
        )
    
    def generate_response(
        self,
        question: str,
        language: str,
        infected_area_pct: float,
        severity: str,
        top_diseases: List[Dict],
        crop: str
    ) -> Tuple[str, List[str], float, Dict[str, Any]]:
        
        try:
            tools = [
                {
                    "type": "function",
                    "function": {
                        "name": "provide_agricultural_advice",
                        "description": "Provide agricultural advice to farmers about crop diseases",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "answer": {
                                    "type": "string",
                                    "description": f"Detailed answer to farmer's question in {language} language"
                                },
                                "actions": {
                                    "type": "array",
                                    "items": {
                                        "type": "object",
                                        "properties": {
                                            "action": {"type": "string", "description": "Specific action to take"},
                                            "priority": {"type": "string", "enum": ["high", "medium", "low"]},
                                            "timing": {"type": "string", "description": "When to perform this action"}
                                        },
                                        "required": ["action", "priority", "timing"]
                                    },
                                    "description": "List of actionable recommendations"
                                },
                                "confidence": {
                                    "type": "number",
                                    "minimum": 0.0,
                                    "maximum": 1.0,
                                    "description": "Confidence level in the recommendation"
                                },
                                "safety_notes": {
                                    "type": "array",
                                    "items": {"type": "string"},
                                    "description": "Important safety considerations"
                                }
                            },
                            "required": ["answer", "actions", "confidence", "safety_notes"]
                        }
                    }
                }
            ]
            
            system_prompt = self._get_system_prompt(language)
            user_prompt = self._build_user_prompt(question, language, infected_area_pct, severity, top_diseases, crop)
            
            response = self.client.chat.completions.create(
                model="llama-3.1-70b-versatile",
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_prompt}
                ],
                tools=tools,
                tool_choice="required",
                max_tokens=1000,
                temperature=0.3
            )
            
            if response.choices[0].message.tool_calls:
                tool_call = response.choices[0].message.tool_calls[0]
                function_args = json.loads(tool_call.function.arguments)
                
                answer = function_args.get("answer", "")
                actions_data = function_args.get("actions", [])
                confidence = function_args.get("confidence", 0.5)
                
                actions = [action["action"] for action in actions_data]
                
                extracted_facts = {
                    "infected_area_pct": infected_area_pct,
                    "severity": severity,
                    "probable_diseases": [disease["label"] for disease in top_diseases[:2]]
                }
                
                return answer, actions, confidence, extracted_facts
            else:
                return self._get_fallback_response(question, language, infected_area_pct, severity, top_diseases)
                
        except Exception as e:
            print(f"Error calling Groq API: {e}")
            return self._get_fallback_response(question, language, infected_area_pct, severity, top_diseases)
    
    def _get_system_prompt(self, language: str) -> str:
        if language.lower() in ['hi', 'hindi']:
            return """आप एक अनुभवी कृषि विशेषज्ञ हैं जो किसानों को फसल की बीमारी के बारे में सलाह देते हैं।

महत्वपूर्ण दिशा-निर्देश:
- हमेशा व्यावहारिक और सुरक्षित सुझाव दें
- कभी भी विशिष्ट कीटनाशक की मात्रा न बताएं
- हमेशा स्थानीय कृषि विशेषज्ञ से सलाह लेने को कहें
- दिए गए function calling format का उपयोग करें
- उत्तर हिंदी में दें"""
        else:
            return """You are an experienced agricultural expert providing advice to farmers about crop diseases.

Important guidelines:
- Always provide practical and safe recommendations
- Never provide specific pesticide dosages
- Always recommend consulting local agricultural experts
- Use the provided function calling format
- Respond in English unless specified otherwise"""
    
    def _build_user_prompt(self, question: str, language: str, infected_area_pct: float, severity: str, top_diseases: List[Dict], crop: str) -> str:
        disease_info = ', '.join([f"{d['label']} ({d['score']:.2f})" for d in top_diseases[:3]])
        
        prompt = f"""
Disease Analysis Context:
- Crop: {crop}
- Infected Area: {infected_area_pct:.1f}%
- Severity Level: {severity}
- Detected Diseases: {disease_info}

Farmer's Question: "{question}"
Response Language: {language}

Please use the provide_agricultural_advice function to give a comprehensive response that:
1. Directly answers the farmer's question
2. Provides specific, actionable steps based on the disease analysis
3. Includes appropriate timing for each action
4. Maintains safety by avoiding specific chemical dosages
5. Emphasizes consulting local experts for precise treatments
"""
        return prompt
    
    def _get_fallback_response(
        self, 
        question: str, 
        language: str, 
        infected_area_pct: float, 
        severity: str, 
        top_diseases: List[Dict]
    ) -> Tuple[str, List[str], float, Dict[str, Any]]:
        
        # Helper function to get disease label
        def get_disease_label(disease):
            if hasattr(disease, 'label'):
                return disease.label
            elif isinstance(disease, dict):
                return disease['label']
            else:
                return str(disease)
        
        primary_disease = get_disease_label(top_diseases[0]) if top_diseases else 'अज्ञात'
        
        if language.lower() in ['hi', 'hindi']:
            answer = f"""आपकी फसल में {infected_area_pct:.1f}% क्षेत्र प्रभावित है और स्थिति {severity} है। 
मुख्य बीमारी {primary_disease} हो सकती है। 

तत्काल कार्रवाई की सिफारिश:
1. प्रभावित पत्तियों को तुरंत हटाएं
2. पानी की मात्रा को नियंत्रित करें
3. स्थानीय कृषि केंद्र से संपर्क करें

कृपया किसी भी रासायनिक उपचार से पहले कृषि विशेषज्ञ की सलाह अवश्य लें।"""
            
            actions = [
                "प्रभावित भागों को तुरंत हटाएं और जलाएं",
                "पानी की मात्रा नियंत्रित करें", 
                "24 घंटे में कृषि विशेषज्ञ से मिलें",
                "अन्य पौधों में फैलने से रोकें"
            ]
        else:
            primary_disease_en = get_disease_label(top_diseases[0]) if top_diseases else 'Unknown'
            answer = f"""Your crop shows {infected_area_pct:.1f}% infection with {severity} severity level. 
The primary disease appears to be {primary_disease_en}. 

Immediate recommendations:
1. Remove affected plant parts immediately
2. Control irrigation and water management
3. Contact your local agricultural extension center
4. Prevent spread to healthy plants

Please consult an agricultural expert before applying any chemical treatments."""
            
            actions = [
                "Remove and burn affected plant parts immediately",
                "Adjust water management practices",
                "Consult agricultural expert within 24 hours",
                "Implement quarantine measures"
            ]
        
        confidence = 0.65
        extracted_facts = {
            "infected_area_pct": infected_area_pct,
            "severity": severity,
            "probable_diseases": [get_disease_label(top_diseases[0])] if top_diseases else ["Unknown"]
        }
        
        return answer, actions, confidence, extracted_facts