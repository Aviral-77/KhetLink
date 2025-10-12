from reportlab.lib.pagesizes import letter, A4
from reportlab.lib import colors
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import inch
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Image as RLImage, Table, TableStyle
from reportlab.lib.enums import TA_CENTER, TA_LEFT
from PIL import Image
import os
from datetime import datetime
from typing import Optional

class PDFService:
    def __init__(self):
        self.styles = getSampleStyleSheet()
        self._setup_custom_styles()
    
    def _setup_custom_styles(self):
        self.title_style = ParagraphStyle(
            'CustomTitle',
            parent=self.styles['Heading1'],
            fontSize=24,
            textColor=colors.darkgreen,
            alignment=TA_CENTER,
            spaceAfter=30
        )
        
        self.header_style = ParagraphStyle(
            'CustomHeader',
            parent=self.styles['Heading2'],
            fontSize=16,
            textColor=colors.darkblue,
            spaceAfter=12
        )
        
        self.body_style = ParagraphStyle(
            'CustomBody',
            parent=self.styles['Normal'],
            fontSize=12,
            alignment=TA_LEFT,
            spaceAfter=8
        )
    
    def generate_claim_report(
        self,
        claim_id: str,
        farmer_id: str,
        image_path: str,
        mask_path: Optional[str],
        overlay_path: Optional[str],
        infected_area_pct: float,
        severity: str,
        top_diseases: list,
        confidence: float,
        latitude: Optional[float],
        longitude: Optional[float],
        capture_ts: Optional[datetime],
        crop: str,
        include_mask: bool = True,
        include_location: bool = True
    ) -> str:
        
        reports_dir = "reports"
        os.makedirs(reports_dir, exist_ok=True)
        
        pdf_path = os.path.join(reports_dir, f"claim_{claim_id}.pdf")
        
        doc = SimpleDocTemplate(pdf_path, pagesize=A4, topMargin=0.5*inch)
        story = []
        
        story.append(Paragraph("KhetLink AI - Crop Disease Analysis Report", self.title_style))
        story.append(Spacer(1, 20))
        
        report_info = [
            ["Report ID:", claim_id],
            ["Farmer ID:", farmer_id],
            ["Crop Type:", crop.title()],
            ["Analysis Date:", datetime.now().strftime("%Y-%m-%d %H:%M:%S")],
            ["Report Generated:", datetime.now().strftime("%Y-%m-%d %H:%M:%S")]
        ]
        
        if capture_ts:
            report_info.insert(4, ["Photo Captured:", capture_ts.strftime("%Y-%m-%d %H:%M:%S")])
        
        info_table = Table(report_info, colWidths=[2*inch, 3*inch])
        info_table.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (0, -1), colors.lightgrey),
            ('TEXTCOLOR', (0, 0), (-1, -1), colors.black),
            ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
            ('FONTNAME', (0, 0), (-1, -1), 'Helvetica'),
            ('FONTSIZE', (0, 0), (-1, -1), 10),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 8),
            ('GRID', (0, 0), (-1, -1), 1, colors.black)
        ]))
        
        story.append(info_table)
        story.append(Spacer(1, 20))
        
        story.append(Paragraph("Disease Analysis Results", self.header_style))
        
        analysis_data = [
            ["Metric", "Value"],
            ["Infected Area Percentage", f"{infected_area_pct:.1f}%"],
            ["Severity Level", severity],
            ["Analysis Confidence", f"{confidence:.1f}%"]
        ]
        
        for i, disease in enumerate(top_diseases[:3]):
            analysis_data.append([f"Disease {i+1}", f"{disease['label']} ({disease['score']:.1f}%)"])
        
        analysis_table = Table(analysis_data, colWidths=[2.5*inch, 2.5*inch])
        analysis_table.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, 0), colors.darkblue),
            ('TEXTCOLOR', (0, 0), (-1, 0), colors.whitesmoke),
            ('BACKGROUND', (0, 1), (-1, -1), colors.beige),
            ('TEXTCOLOR', (0, 1), (-1, -1), colors.black),
            ('ALIGN', (0, 0), (-1, -1), 'CENTER'),
            ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
            ('FONTNAME', (0, 1), (-1, -1), 'Helvetica'),
            ('FONTSIZE', (0, 0), (-1, -1), 10),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 8),
            ('GRID', (0, 0), (-1, -1), 1, colors.black)
        ]))
        
        story.append(analysis_table)
        story.append(Spacer(1, 20))
        
        if os.path.exists(image_path):
            story.append(Paragraph("Original Image", self.header_style))
            
            try:
                with Image.open(image_path) as img:
                    img_width, img_height = img.size
                    aspect_ratio = img_height / img_width
                    
                    display_width = 4 * inch
                    display_height = display_width * aspect_ratio
                    
                    if display_height > 3 * inch:
                        display_height = 3 * inch
                        display_width = display_height / aspect_ratio
                
                story.append(RLImage(image_path, width=display_width, height=display_height))
                story.append(Spacer(1, 15))
            except Exception as e:
                story.append(Paragraph(f"Error loading image: {e}", self.body_style))
        
        if include_mask and mask_path and os.path.exists(mask_path):
            story.append(Paragraph("Disease Segmentation Mask", self.header_style))
            try:
                story.append(RLImage(mask_path, width=4*inch, height=3*inch))
                story.append(Spacer(1, 15))
            except Exception as e:
                story.append(Paragraph(f"Error loading mask: {e}", self.body_style))
        
        if include_location and latitude and longitude:
            story.append(Paragraph("Location Information", self.header_style))
            location_data = [
                ["Latitude", f"{latitude:.6f}"],
                ["Longitude", f"{longitude:.6f}"],
                ["Coordinates", f"{latitude:.6f}, {longitude:.6f}"]
            ]
            
            location_table = Table(location_data, colWidths=[1.5*inch, 3.5*inch])
            location_table.setStyle(TableStyle([
                ('BACKGROUND', (0, 0), (0, -1), colors.lightgrey),
                ('TEXTCOLOR', (0, 0), (-1, -1), colors.black),
                ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
                ('FONTNAME', (0, 0), (-1, -1), 'Helvetica'),
                ('FONTSIZE', (0, 0), (-1, -1), 10),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 8),
                ('GRID', (0, 0), (-1, -1), 1, colors.black)
            ]))
            
            story.append(location_table)
            story.append(Spacer(1, 20))
        
        story.append(Paragraph("Disclaimer", self.header_style))
        disclaimer_text = """
        This report is generated by KhetLink AI for informational purposes only. 
        The analysis is based on computer vision and machine learning algorithms. 
        For accurate diagnosis and treatment recommendations, please consult with a qualified agricultural expert or extension officer.
        
        This report can be used as supporting documentation for crop insurance claims, 
        but final decisions rest with the insurance provider and their assessment procedures.
        """
        story.append(Paragraph(disclaimer_text, self.body_style))
        story.append(Spacer(1, 30))
        
        signature_text = """
        ________________________________
        Farmer Signature
        
        Date: ________________
        """
        story.append(Paragraph(signature_text, self.body_style))
        
        doc.build(story)
        
        return pdf_path