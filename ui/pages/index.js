import React, { useState, useRef, useEffect } from "react";
import { useSession, signIn } from "next-auth/react";
import { Send, Bot, User, Loader } from "lucide-react";

export default function Chatbot() {
  const { data: session } = useSession();
  const [messages, setMessages] = useState([]);
  const [input, setInput] = useState("");
  const [isLoading, setIsLoading] = useState(false);
  const messagesEndRef = useRef(null);

  // Auto-scroll to bottom when messages update
  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages]);

  const sendMessage = async () => {
    if (!input.trim() || isLoading) return;
  
    const userMessage = { role: "user", text: input };
    setMessages(prev => [...prev, userMessage]);
    setInput("");
    setIsLoading(true);
  
    try {
      console.log("Sending message to API:", input);
      
      const response = await fetch(`${process.env.NEXT_PUBLIC_API_BASE_URL}/chat`, {
        method: "POST",
        headers: { 
          "Content-Type": "application/json"
        },
        body: JSON.stringify({ message: input }),
      });
      
      console.log("API response status:", response.status);
      
      if (!response.ok) {
        throw new Error(`API responded with status: ${response.status}`);
      }
      
      // Handle response
      const data = await response.json();
      console.log("API response data:", data);
      
      const botMessage = { 
        role: "bot", 
        text: data.text || "Sorry, I couldn't generate a response."
      };
      setMessages(prev => [...prev, botMessage]);
    } catch (error) {
      console.error("Error sending message:", error);
      const errorMessage = { 
        role: "error", 
        text: `Error: ${error.message}. Please try again later.` 
      };
      setMessages(prev => [...prev, errorMessage]);
    } finally {
      setIsLoading(false);
    }
  };

  if (!session) {
    return (
      <div className="login-container">
        <div className="login-card">
          <div className="login-icon">
            <Bot size={48} />
          </div>
          <h1 className="login-title">CloudSageAI</h1>
          <p className="login-subtitle">AI-Powered DevOps Assistant</p>
          <button 
            className="login-button"
            onClick={() => signIn('azure-ad', { callbackUrl: '/' })}
          >
            Sign in with Azure AD
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="chat-container">
      {/* Header */}
      <header className="chat-header">
        <div className="header-content">
          <div className="header-title">
            <Bot size={24} />
            <h1>CloudSageAI</h1>
          </div>
        </div>
      </header>

      {/* Chat Messages */}
      <div className="messages-container">
        {messages.length === 0 ? (
          <div className="welcome-message">
            <Bot size={64} />
            <h2>Welcome to CloudSageAI</h2>
            <p>
              Ask me anything about DevOps, cloud engineering, or search for information in your Jira tickets and Confluence pages.
            </p>
          </div>
        ) : (
          messages.map((msg, index) => (
            <div 
              key={index} 
              className={`message ${msg.role === "user" ? "user-message" : msg.role === "error" ? "error-message" : "bot-message"}`}
            >
              <div className="message-header">
                {msg.role === "user" ? (
                  <>
                    <span>You</span>
                    <User size={14} />
                  </>
                ) : (
                  <>
                    <span>CloudSageAI</span>
                    <Bot size={14} />
                  </>
                )}
              </div>
              <div className="message-content">{msg.text}</div>
            </div>
          ))
        )}
        {isLoading && (
          <div className="message bot-message">
            <div className="message-header">
              <span>CloudSageAI</span>
              <Bot size={14} />
            </div>
            <div className="message-content loading">
              <Loader size={16} className="loading-spinner" />
              <span>Thinking...</span>
            </div>
          </div>
        )}
        <div ref={messagesEndRef} />
      </div>

      {/* Input Area */}
      <div className="input-container">
        <div className="input-wrapper">
          <input
            type="text"
            value={input}
            onChange={(e) => setInput(e.target.value)}
            placeholder="Ask something..."
            onKeyPress={(e) => e.key === 'Enter' && sendMessage()}
            disabled={isLoading}
            className="message-input"
          />
          <button 
            onClick={sendMessage} 
            disabled={isLoading || !input.trim()}
            className="send-button"
          >
            <Send size={18} />
          </button>
        </div>
      </div>
    </div>
  );
}