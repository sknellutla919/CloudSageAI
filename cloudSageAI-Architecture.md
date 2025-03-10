<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 900 600">
  <!-- Background -->
  <rect width="900" height="600" fill="#f8f9fa"/>
  
  <!-- Title -->
  <text x="450" y="40" font-family="Arial" font-size="24" text-anchor="middle" font-weight="bold" fill="#212529">CloudSageAI Architecture</text>
  
  <!-- Data Sources Section -->
  <rect x="40" y="80" width="180" height="120" rx="10" ry="10" fill="#e9ecef" stroke="#adb5bd" stroke-width="2"/>
  <text x="130" y="110" font-family="Arial" font-size="16" text-anchor="middle" font-weight="bold" fill="#495057">External Data Sources</text>
  
  <rect x="60" y="125" width="140" height="25" rx="5" ry="5" fill="#fff" stroke="#6c757d" stroke-width="1"/>
  <text x="130" y="142" font-family="Arial" font-size="12" text-anchor="middle" fill="#495057">Jira</text>
  
  <rect x="60" y="155" width="140" height="25" rx="5" ry="5" fill="#fff" stroke="#6c757d" stroke-width="1"/>
  <text x="130" y="172" font-family="Arial" font-size="12" text-anchor="middle" fill="#495057">Confluence</text>
  
  <!-- Data Extraction Layer -->
  <rect x="250" y="80" width="160" height="160" rx="10" ry="10" fill="#daeafc" stroke="#4a7ebb" stroke-width="2"/>
  <text x="330" y="110" font-family="Arial" font-size="16" text-anchor="middle" font-weight="bold" fill="#0d6efd">Data Extraction Layer</text>
  
  <rect x="270" y="125" width="120" height="25" rx="5" ry="5" fill="#fff" stroke="#0d6efd" stroke-width="1"/>
  <text x="330" y="142" font-family="Arial" font-size="12" text-anchor="middle" fill="#0d6efd">Azure Function App</text>
  
  <rect x="270" y="155" width="120" height="25" rx="5" ry="5" fill="#fff" stroke="#0d6efd" stroke-width="1"/>
  <text x="330" y="172" font-family="Arial" font-size="12" text-anchor="middle" fill="#0d6efd">Vision AI</text>
  
  <rect x="270" y="185" width="120" height="25" rx="5" ry="5" fill="#fff" stroke="#0d6efd" stroke-width="1"/>
  <text x="330" y="202" font-family="Arial" font-size="12" text-anchor="middle" fill="#0d6efd">Document Intelligence</text>
  
  <!-- Data Storage Layer -->
  <rect x="250" y="260" width="320" height="80" rx="10" ry="10" fill="#e2f1e7" stroke="#52b788" stroke-width="2"/>
  <text x="410" y="290" font-family="Arial" font-size="16" text-anchor="middle" font-weight="bold" fill="#198754">Data Storage Layer</text>
  
  <rect x="270" y="305" width="120" height="25" rx="5" ry="5" fill="#fff" stroke="#198754" stroke-width="1"/>
  <text x="330" y="322" font-family="Arial" font-size="12" text-anchor="middle" fill="#198754">Cosmos DB</text>
  
  <rect x="430" y="305" width="120" height="25" rx="5" ry="5" fill="#fff" stroke="#198754" stroke-width="1"/>
  <text x="490" y="322" font-family="Arial" font-size="12" text-anchor="middle" fill="#198754">Azure Cognitive Search</text>
  
  <!-- Data Processing Layer -->
  <rect x="440" y="80" width="180" height="160" rx="10" ry="10" fill="#f8d7da" stroke="#dc3545" stroke-width="2"/>
  <text x="530" y="110" font-family="Arial" font-size="16" text-anchor="middle" font-weight="bold" fill="#dc3545">AI Processing Layer</text>
  
  <rect x="460" y="125" width="140" height="25" rx="5" ry="5" fill="#fff" stroke="#dc3545" stroke-width="1"/>
  <text x="530" y="142" font-family="Arial" font-size="12" text-anchor="middle" fill="#dc3545">Azure OpenAI GPT-4</text>
  
  <rect x="460" y="155" width="140" height="25" rx="5" ry="5" fill="#fff" stroke="#dc3545" stroke-width="1"/>
  <text x="530" y="172" font-family="Arial" font-size="12" text-anchor="middle" fill="#dc3545">RAG Integration</text>
  
  <rect x="460" y="185" width="140" height="25" rx="5" ry="5" fill="#fff" stroke="#dc3545" stroke-width="1"/>
  <text x="530" y="202" font-family="Arial" font-size="12" text-anchor="middle" fill="#dc3545">Content Safety</text>
  
  <!-- Application Layer -->
  <rect x="650" y="80" width="180" height="120" rx="10" ry="10" fill="#fff3cd" stroke="#ffc107" stroke-width="2"/>
  <text x="740" y="110" font-family="Arial" font-size="16" text-anchor="middle" font-weight="bold" fill="#fd7e14">Application Layer</text>
  
  <rect x="670" y="125" width="140" height="25" rx="5" ry="5" fill="#fff" stroke="#fd7e14" stroke-width="1"/>
  <text x="740" y="142" font-family="Arial" font-size="12" text-anchor="middle" fill="#fd7e14">Next.js API</text>
  
  <rect x="670" y="155" width="140" height="25" rx="5" ry="5" fill="#fff" stroke="#fd7e14" stroke-width="1"/>
  <text x="740" y="172" font-family="Arial" font-size="12" text-anchor="middle" fill="#fd7e14">React UI</text>
  
  <!-- User Access Layer -->
  <rect x="650" y="220" width="180" height="120" rx="10" ry="10" fill="#d3d3f9" stroke="#6f42c1" stroke-width="2"/>
  <text x="740" y="250" font-family="Arial" font-size="16" text-anchor="middle" font-weight="bold" fill="#6f42c1">Access Layer</text>
  
  <rect x="670" y="265" width="140" height="25" rx="5" ry="5" fill="#fff" stroke="#6f42c1" stroke-width="1"/>
  <text x="740" y="282" font-family="Arial" font-size="12" text-anchor="middle" fill="#6f42c1">Azure API Management</text>
  
  <rect x="670" y="295" width="140" height="25" rx="5" ry="5" fill="#fff" stroke="#6f42c1" stroke-width="1"/>
  <text x="740" y="312" font-family="Arial" font-size="12" text-anchor="middle" fill="#6f42c1">Azure AD Authentication</text>
  
  <!-- Infrastructure Layer -->
  <rect x="60" y="360" width="780" height="80" rx="10" ry="10" fill="#343a40" stroke="#212529" stroke-width="2"/>
  <text x="450" y="390" font-family="Arial" font-size="16" text-anchor="middle" font-weight="bold" fill="#fff">Infrastructure Layer</text>
  
  <rect x="120" y="405" width="120" height="25" rx="5" ry="5" fill="#fff" stroke="#6c757d" stroke-width="1"/>
  <text x="180" y="422" font-family="Arial" font-size="12" text-anchor="middle" fill="#212529">Bicep Templates</text>
  
  <rect x="260" y="405" width="120" height="25" rx="5" ry="5" fill="#fff" stroke="#6c757d" stroke-width="1"/>
  <text x="320" y="422" font-family="Arial" font-size="12" text-anchor="middle" fill="#212529">Container Apps</text>
  
  <rect x="400" y="405" width="120" height="25" rx="5" ry="5" fill="#fff" stroke="#6c757d" stroke-width="1"/>
  <text x="460" y="422" font-family="Arial" font-size="12" text-anchor="middle" fill="#212529">Private Networking</text>
  
  <rect x="540" y="405" width="120" height="25" rx="5" ry="5" fill="#fff" stroke="#6c757d" stroke-width="1"/>
  <text x="600" y="422" font-family="Arial" font-size="12" text-anchor="middle" fill="#212529">Azure DevOps</text>
  
  <rect x="680" y="405" width="120" height="25" rx="5" ry="5" fill="#fff" stroke="#6c757d" stroke-width="1"/>
  <text x="740" y="422" font-family="Arial" font-size="12" text-anchor="middle" fill="#212529">Azure Monitor</text>
  
  <!-- User Group -->
  <rect x="650" y="460" width="180" height="80" rx="50" ry="50" fill="#e9ecef" stroke="#adb5bd" stroke-width="2"/>
  <text x="740" y="510" font-family="Arial" font-size="16" text-anchor="middle" font-weight="bold" fill="#495057">DevOps Teams</text>
  
  <!-- Connecting Lines -->
  <!-- Data Sources to Extraction -->
  <line x1="220" y1="140" x2="250" y2="140" stroke="#6c757d" stroke-width="2"/>
  <polygon points="245,135 255,140 245,145" fill="#6c757d"/>
  
  <!-- Extraction to Storage -->
  <line x1="330" y1="240" x2="330" y2="260" stroke="#4a7ebb" stroke-width="2"/>
  <polygon points="325,255 330,265 335,255" fill="#4a7ebb"/>
  
  <!-- Processing to Storage -->
  <line x1="490" y1="240" x2="490" y2="260" stroke="#dc3545" stroke-width="2"/>
  <polygon points="485,255 490,265 495,255" fill="#dc3545"/>
  
  <!-- Storage to Processing -->
  <line x1="410" y1="260" x2="410" y2="160" stroke="#198754" stroke-width="2"/>
  <polygon points="405,165 410,155 415,165" fill="#198754"/>
  
  <!-- Processing to Application -->
  <line x1="620" y1="140" x2="650" y2="140" stroke="#dc3545" stroke-width="2"/>
  <polygon points="645,135 655,140 645,145" fill="#dc3545"/>
  
  <!-- Application to Access -->
  <line x1="740" y1="200" x2="740" y2="220" stroke="#fd7e14" stroke-width="2"/>
  <polygon points="735,215 740,225 745,215" fill="#fd7e14"/>
  
  <!-- Access to Users -->
  <line x1="740" y1="340" x2="740" y2="460" stroke="#6f42c1" stroke-width="2"/>
  <polygon points="735,455 740,465 745,455" fill="#6f42c1"/>
  
  <!-- Infrastructure to All Layers -->
  <line x1="180" y1="360" x2="180" y2="200" stroke="#212529" stroke-width="2"/>
  <polygon points="175,205 180,195 185,205" fill="#212529"/>
  
  <line x1="320" y1="360" x2="320" y2="240" stroke="#212529" stroke-width="2"/>
  <polygon points="315,245 320,235 325,245" fill="#212529"/>
  
  <line x1="460" y1="360" x2="460" y2="260" stroke="#212529" stroke-width="2"/>
  <polygon points="455,265 460,255 465,265" fill="#212529"/>
  
  <line x1="600" y1="360" x2="600" y2="200" stroke="#212529" stroke-width="2"/>
  <polygon points="595,205 600,195 605,205" fill="#212529"/>
  
  <line x1="740" y1="360" x2="740" y2="340" stroke="#212529" stroke-width="2"/>
  <polygon points="735,345 740,335 745,345" fill="#212529"/>
  
  <!-- Data Flow Description -->
  <rect x="60" y="460" width="550" height="120" rx="10" ry="10" fill="#F8F9FA" stroke="#DEE2E6" stroke-width="2"/>
  <text x="70" y="485" font-family="Arial" font-size="16" font-weight="bold" fill="#212529">Data Flow:</text>
  <text x="70" y="515" font-family="Arial" font-size="12" fill="#495057">1. Data is extracted from Jira/Confluence via Azure Functions and processed by Vision/Document Intelligence</text>
  <text x="70" y="535" font-family="Arial" font-size="12" fill="#495057">2. Structured data is stored in Cosmos DB and indexed by Azure Cognitive Search</text>
  <text x="70" y="555" font-family="Arial" font-size="12" fill="#495057">3. User queries trigger OpenAI with RAG integration to search relevant knowledge</text>
  <text x="70" y="575" font-family="Arial" font-size="12" fill="#495057">4. API processes responses and returns context-aware answers to the UI</text>
</svg>