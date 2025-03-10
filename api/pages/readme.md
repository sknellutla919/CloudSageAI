# CloudSageAI - API Component

This directory contains the API backend for CloudSageAI, built using Next.js API routes. The API is responsible for handling user queries, communicating with Azure OpenAI via RAG, and ensuring content safety.

## 📋 Overview

The API component serves as the bridge between the user interface and the Azure AI services. It processes incoming chat requests, filters inappropriate content, queries OpenAI with Retrieval-Augmented Generation (RAG), and returns AI-generated responses.

## 🔧 Key Components

### 1. `chat.js` - Core RAG Query Handler

The central component of the API is the `chat.js` file, which:

- Receives user queries from the UI
- Filters inappropriate content via Azure Content Safety
- Implements RAG by calling Azure OpenAI with data_sources configuration
- Formats and returns AI-generated responses
- Logs interactions via Application Insights

### 2. `auth.js` - Authentication Handler

This component manages Azure AD authentication with NextAuth.js:

- Configures Azure AD as the identity provider
- Handles login/logout flows
- Secures API endpoints
- Maintains user sessions

### 3. `health.js` - Health Check Endpoint

A simple endpoint that returns the API's health status:

- Used by monitoring systems
- Provides timestamp for freshness verification

## 📦 Technical Implementation

### RAG Integration

The most significant technical aspect is the implementation of Retrieval-Augmented Generation:

```javascript
// Example from chat.js
const openAiResponse = await fetch(`${AZURE_OPENAI_ENDPOINT}/openai/deployments/gpt-4-turbo/chat/completions?api-version=2023-12-01-preview`, {
  method: "POST",
  headers: {
    "Content-Type": "application/json",
    "api-key": AZURE_OPENAI_API_KEY,
  },
  body: JSON.stringify({
    messages: [
      { 
        role: "system", 
        content: "You are CloudSageAI, an assistant that helps with DevOps and cloud questions. When answering questions, always check if the retrieved documents contain relevant information. If they do, provide that specific information clearly. If information is found but seems incomplete, acknowledge what was found and state that details are limited." 
      },
      { role: "user", content: message }
    ],
    max_tokens: 800,
    temperature: 0.5,
    stream: false,
    data_sources: [
      {
        type: "azure_search",
        parameters: {
          endpoint: AZURE_COGNITIVE_SEARCH_ENDPOINT,
          index_name: "jira_confluence_knowledge",
          authentication: {
            type: "api_key",
            key: AZURE_COGNITIVE_SEARCH_API_KEY
          },
          query_type: "simple", 
          top_k: 10
        }
      }
    ]
  }),
});
```

This implementation allows the API to:
1. Connect to Azure Cognitive Search
2. Retrieve relevant documents based on the user query
3. Include those documents as context for the OpenAI model
4. Generate a response that incorporates the retrieved information

### Content Safety

To ensure appropriate use, the API implements content moderation:

```javascript
async function moderateContent(message) {
  try {
    const response = await fetch(`${AZURE_CONTENT_SAFETY_ENDPOINT}/contentsafety/text:analyze?api-version=2023-10-01-preview`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Ocp-Apim-Subscription-Key": AZURE_CONTENT_SAFETY_KEY,
      },
      body: JSON.stringify({
        text: message,
        categories: ["Hate", "Sexual", "SelfHarm", "Violence"], 
        severityThreshold: 3,
      }),
    });

    // Process response and determine if content is inappropriate
    // ...
  } catch (error) {
    // Error handling
  }
}
```

### Analytics and Monitoring

Application Insights integration provides observability:

```javascript
appInsights = new ApplicationInsights({
  config: { instrumentationKey: process.env.APPINSIGHTS_INSTRUMENTATIONKEY },
});
appInsights.loadAppInsights();
appInsights.trackEvent({ name: "Chatbot Request", properties: { userQuery: message } });
```

## 🛠️ Development Guide

### Local Development Setup

1. Clone the repository
2. Navigate to the `/api` directory
3. Create a `.env.local` file with the following variables:

```
AZURE_OPENAI_ENDPOINT=https://your-openai-resource.openai.azure.com/
AZURE_OPENAI_API_KEY=your-openai-key
AZURE_COGNITIVE_SEARCH_ENDPOINT=https://your-search-resource.search.windows.net
AZURE_COGNITIVE_SEARCH_API_KEY=your-search-key
AZURE_CONTENT_SAFETY_ENDPOINT=https://your-content-safety.cognitiveservices.azure.com/
AZURE_CONTENT_SAFETY_KEY=your-content-safety-key
AZURE_AD_CLIENT_ID=your-app-registration-client-id
AZURE_AD_CLIENT_SECRET=your-app-registration-client-secret
AZURE_AD_TENANT_ID=your-tenant-id
APPINSIGHTS_INSTRUMENTATIONKEY=your-app-insights-key
NEXTAUTH_URL=http://localhost:3001
NEXTAUTH_SECRET=a-random-string-for-local-development
```

4. Install dependencies:
```bash
npm install
```

5. Run the development server:
```bash
npm run dev -- -p 3001
```

### Making Changes

When modifying the RAG implementation:

1. Consider updating the system prompt to improve context utilization
2. Test with various query types to ensure accurate retrieval
3. Monitor Azure OpenAI costs and adjust parameters as needed

When modifying authentication:

1. Ensure redirect URIs are properly configured in both Azure AD and the application
2. Test session persistence and token refresh flows
3. Consider implementing role-based access if needed

## 📊 Monitoring and Debugging

### Logs

API logs can be viewed in:
- Application Insights traces
- Container App logs
- Standard console output during local development

### Common Issues

1. **Authentication Failures**
   - Check Azure AD app registration configuration
   - Verify NEXTAUTH_URL matches the actual deployment URL

2. **Search Integration Issues**
   - Verify index exists and contains documents
   - Check search parameter formatting in the API call

3. **OpenAI Rate Limiting**
   - Implement retry logic for transient failures
   - Monitor usage and adjust application scale accordingly

## 🔒 Security Considerations

- All sensitive keys should be stored in environment variables
- Authentication is implemented via Azure AD
- Content moderation prevents inappropriate use
- Private endpoints ensure secure service-to-service communication

## 🔄 Deployment

The API is deployed as a Docker container through Azure DevOps pipelines. The Dockerfile in this directory defines the container image.

## 🔗 Links to Related Documentation

- [Next.js API Routes](https://nextjs.org/docs/api-routes/introduction)
- [Azure OpenAI REST API](https://learn.microsoft.com/en-us/azure/ai-services/openai/reference)
- [Azure Cognitive Search](https://learn.microsoft.com/en-us/azure/search/search-what-is-azure-search)
- [NextAuth.js with Azure AD](https://next-auth.js.org/providers/azure-ad)