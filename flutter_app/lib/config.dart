// Central config for API keys and endpoints used across the app.
// WARNING: This file contains hardcoded values for development convenience.
// Do not commit secrets or production keys to a public repo. Replace with a
// secure mechanism (env vars, secret manager) for production use.

// RapidAPI (Nokia Network-as-Code)
// NOTE: Placeholder value. Set the real key via environment variable or
// replace this with a secure retrieval mechanism in your CI/CD.
const String RAPIDAPI_KEY = 'REPLACE_WITH_RAPIDAPI_KEY';
const String NETWORK_AS_CODE_HOST = 'network-as-code.nokia.rapidapi.com';
const String NETWORK_AS_CODE_URL = 'https://network-as-code.p-eu.rapidapi.com/location-retrieval/v0/retrieve';

// Google Earth Engine / GEE backend (MRV)
const String GEE_BASE = 'https://geoserver.bluehawk.ai:8045/gee';

// AI analysis backend (local/dev IP)
const String AI_ANALYSIS_BASE = 'http://10.18.197.126:8085';
const String AI_UPLOAD_ENDPOINT = '$AI_ANALYSIS_BASE/upload-remote';
const String AI_ANALYZE_ENDPOINT = '$AI_ANALYSIS_BASE/analyze';
const String AI_POLL_ENDPOINT = '$AI_ANALYSIS_BASE/analyze'; // append /{job_id}
const String AI_CHAT_ENDPOINT = '$AI_ANALYSIS_BASE/chat-query';

// Test S3 image (simulated upload)
const String S3_TEST_IMAGE = 'https://testimagesuat.s3.ap-south-1.amazonaws.com/uploads/leaf_img.JPG';

// Helper: build GEE report URL for a record id
String geeReportUrl(dynamic recordId) => '$GEE_BASE/mrv/report/$recordId';
