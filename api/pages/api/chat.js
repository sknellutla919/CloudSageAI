import { getSession } from "next-auth/react";
import { ApplicationInsights } from "@microsoft/applicationinsights-web";

const AZURE_OPENAI_ENDPOINT = process.env.AZURE_OPENAI_ENDPOINT;
const AZURE_OPENAI_API_KEY = process.env.AZURE_OPENAI_API_KEY;
const AZURE_CONTENT_SAFETY_ENDPOINT = process.env.AZURE_CONTENT_SAFETY_ENDPOINT;
const AZURE_CONTENT_SAFETY_KEY = process.env.AZURE_CONTENT_SAFETY_KEY;
const AZURE_COGNITIVE_SEARCH_ENDPOINT = process.env.AZURE_COGNITIVE_SEARCH_ENDPOINT;
const AZURE_COGNITIVE_SEARCH_API_KEY = process.env.AZURE_COGNITIVE_SEARCH_API_KEY;



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

    if (!response.ok) {
      console.error("Content moderation API error:", await response.text());
      return false; 
    }

    const data = await response.json();
    return data.blocked === true;
  } catch (error) {
    console.error("Content moderation error:", error);
    return false;
  }
}

export default async function handler(req, res) {
  // Enable CORS
  res.setHeader('Access-Control-Allow-Credentials', true);
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,OPTIONS,PATCH,DELETE,POST,PUT');
  res.setHeader('Access-Control-Allow-Headers', 'X-CSRF-Token, X-Requested-With, Accept, Accept-Version, Content-Length, Content-MD5, Content-Type, Date, X-Api-Version, Authorization');

  if (req.method === 'OPTIONS') {
    res.status(200).end();
    return;
  }

  if (req.method !== "POST") {
    return res.status(405).json({ error: "Method Not Allowed" });
  }

  try {
    // TEMPORARILY BYPASS AUTHENTICATION
    // const session = await getSession({ req });
    // if (!session) {
    //   return res.status(401).json({ error: "Unauthorized - Please log in" });
    // }

    const { message } = req.body;
    if (!message) {
      return res.status(400).json({ error: "Message is required" });
    }

    // content moderation
     const isInappropriate = await moderateContent(message);
     if (isInappropriate) {
       return res.status(400).json({ error: "Inappropriate content detected. Please rephrase your query." });
     }

    const startTime = Date.now();

    //  Application Insights for now to simplify testing
    let appInsights = null;
    try {
      appInsights = new ApplicationInsights({
        config: { instrumentationKey: process.env.APPINSIGHTS_INSTRUMENTATIONKEY },
      });
      appInsights.loadAppInsights();
      appInsights.trackEvent({ name: "Chatbot Request", properties: { userQuery: message } });
    } catch (insightsError) {
      console.error("Application Insights initialization error:", insightsError);
    }

    // Now directly call OpenAI with the integrated RAG data source
    try {
      console.log("Sending request to OpenAI:", AZURE_OPENAI_ENDPOINT);
      
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
              content: "You are CloudSageAI, a helpful assistant for DevOps and Cloud engineers. When answering questions, prioritize information from the provided context over your general knowledge. If relevant information is found in the context, use it to provide specific answers. Always cite the source (Jira ticket ID or Confluence page) when using information from the context. If no relevant information is found in the context, clearly state that you don't have specific information on that topic but provide a helpful general response based on your knowledge." 
            },
            { role: "user", content: message }
          ],
          max_tokens: 800,
          temperature: 0.7,
          stream: false,
          data_sources: [  
            {
              type: "azure_search",  // Use Azure Cognitive Search as a data source
              parameters: {
                endpoint: AZURE_COGNITIVE_SEARCH_ENDPOINT,
                authentication: {
                  type: "api_key",
                  key: AZURE_COGNITIVE_SEARCH_API_KEY,
                },
                index_name: "jira_confluence_knowledge"
              }
            }
          ]
        }),
      });

      if (!openAiResponse.ok) {
        const errorText = await openAiResponse.text();
        console.error(`OpenAI API error: ${errorText}`);
        throw new Error(`OpenAI API error: ${errorText}`);
      }

      const openAiData = await openAiResponse.json();
      console.log("OpenAI response:", JSON.stringify(openAiData, null, 2));
      
      // Just return the content directly
      if (openAiData.choices && openAiData.choices.length > 0 && openAiData.choices[0].message) {
        const responseTime = Date.now() - startTime;
        return res.status(200).json({ 
          text: openAiData.choices[0].message.content,
          model: openAiData.model,
          responseTime: `${responseTime}ms`
        });
      } else {
        throw new Error("Unexpected response format from OpenAI");
      }
      
    } catch (openAiError) {
      console.error("Error with OpenAI:", openAiError);
      return res.status(500).json({ error: `OpenAI error: ${openAiError.message}` });
    }
  } catch (error) {
    console.error("General error in handler:", error);
    return res.status(500).json({ error: "Internal Server Error", details: error.message });
  }
}