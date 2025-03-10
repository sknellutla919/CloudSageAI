# CloudSageAI - UI Component

This directory contains the user interface for CloudSageAI, built using Next.js and React. The UI provides an intuitive chat interface for interacting with the AI-powered DevOps assistant.

## 📋 Overview

The UI component offers a modern, responsive chat interface that allows DevOps teams to query their Jira and Confluence knowledge base. It connects to the API backend, handles authentication, manages conversation state, and presents AI-generated responses in a user-friendly format.

## 🔧 Key Components

### 1. `index.js` - Main Chat Interface

The heart of the UI is the `index.js` file, which:

- Implements a responsive chat interface
- Handles user input and message submission
- Manages authentication state
- Displays conversation history
- Shows typing indicators during AI response generation
- Formats and displays AI responses with citation information

### 2. `_app.js` - Application Wrapper

This component sets up the application context and authentication provider:

- Configures the NextAuth.js session provider
- Applies global styles
- Initializes Application Insights (when enabled)

### 3. Components Directory

Contains reusable UI components:

- `Button.js` - Styled button components
- `Card.js` - Container components for content
- `Input.js` - Text input components

## 📦 Technical Implementation

### Chat Interface

The chat interface is implemented as a stateful React component:

```javascript
export default function Chatbot() {
  const { data: session } = useSession();
  const [messages, setMessages] = useState([]);
  const [input, setInput] = useState("");
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState(null);
  const messagesEndRef = useRef(null);

  // Auto-scroll to bottom when messages update
  useEffect(() => {
    scrollToBottom();
  }, [messages]);

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: "smooth" });
  };

  const sendMessage = async () => {
    if (!input.trim() || isLoading) return;
  
    const userMessage = { role: "user", text: input };
    setMessages(prev => [...prev, userMessage]);
    setInput("");
    setIsLoading(true);
    setError(null);
  
    try {
      // API call implementation
      // ...

      const botMessage = { 
        role: "bot", 
        text: data.text,
        model: data.model,
        responseTime: data.responseTime
      };
      setMessages(prev => [...prev, botMessage]);
    } catch (error) {
      // Error handling
    } finally {
      setIsLoading(false);
    }
  };

  // Render UI based on auth state and messages
  // ...
}
```

This implementation provides:
- A responsive chat interface
- Visual loading indicators
- Error handling
- Auto-scrolling to new messages

### Authentication Flow

The UI integrates with Azure AD for authentication:

```javascript
// In _app.js
export default function MyApp({ Component, pageProps: { session, ...pageProps } }) {
  return (
    <SessionProvider session={session}>
      <Component {...pageProps} />
    </SessionProvider>
  );
}

// In index.js (auth check)
if (!session) {
  return (
    <div className="flex flex-col items-center justify-center h-screen bg-gray-100">
      <div className="p-8 bg-white rounded-lg shadow-lg max-w-md w-full">
        <h1 className="text-2xl font-bold text-center mb-6">CloudSageAI</h1>
        <p className="mb-6 text-center text-gray-600">Your AI-powered DevOps assistant. Please sign in to access the chatbot.</p>
        <Button onClick={() => signIn('azure-ad', { callbackUrl: '/' })} className="w-full py-2 bg-blue-600 hover:bg-blue-700">
          Sign In with Azure
        </Button>
      </div>
    </div>
  );
}
```

### API Integration

The UI communicates with the backend API:

```javascript
const response = await fetch(`${process.env.NEXT_PUBLIC_API_BASE_URL}/chat`, {
  method: "POST",
  headers: { 
    "Content-Type": "application/json"
  },
  body: JSON.stringify({ message: input }),
});
```

## 🛠️ Development Guide

### Local Development Setup

1. Clone the repository
2. Navigate to the `/ui` directory
3. Create a `.env.local` file with the following variables:

```
NEXT_PUBLIC_API_BASE_URL=http://localhost:3001
AZURE_AD_CLIENT_ID=your-app-registration-client-id
AZURE_AD_CLIENT_SECRET=your-app-registration-client-secret
AZURE_AD_TENANT_ID=your-tenant-id
APPINSIGHTS_INSTRUMENTATIONKEY=your-app-insights-key
NEXTAUTH_URL=http://localhost:3000
NEXTAUTH_SECRET=a-random-string-for-local-development
```

4. Install dependencies:
```bash
npm install
```

5. Run the development server:
```bash
npm run dev
```

6. Open [http://localhost:3000](http://localhost:3000) in your browser

### Making UI Changes

When modifying the UI:

1. **Component Structure**: Keep components modular and reusable
2. **State Management**: Use React hooks for state management
3. **Styling**: Use tailwind classes for consistent styling
4. **Accessibility**: Ensure the UI is accessible (keyboard navigation, screen readers)

### Adding New Features

To add new features to the UI:

1. **File Upload**: Implement file upload for document analysis
2. **User Preferences**: Add user preference settings (theme, message density)
3. **History Management**: Implement conversation history persistence
4. **Visualization**: Add support for data visualization components

## 🎨 UI/UX Design Principles

The UI follows these design principles:

1. **Simplicity**: Clean interface with focus on the conversation
2. **Responsiveness**: Works on desktop and mobile devices
3. **Visual Feedback**: Clear indicators for loading, errors, and success
4. **Accessibility**: Designed to be usable by everyone

## 📊 Monitoring and Analytics

The UI integrates with Application Insights:

- Track user interactions
- Monitor performance metrics
- Analyze feature usage
- Capture errors and exceptions

## 🔒 Security Considerations

- Client-side validation is implemented but never replaces server-side validation
- Authentication tokens are securely handled through NextAuth.js
- Sensitive configuration is stored in environment variables
- Content Security Policy headers are configured

## 🔄 Deployment

The UI is deployed as a Docker container through Azure DevOps pipelines. The Dockerfile in this directory defines the container image.

## 🔗 Links to Related Documentation

- [Next.js Documentation](https://nextjs.org/docs)
- [React Documentation](https://reactjs.org/docs/getting-started.html)
- [NextAuth.js](https://next-auth.js.org/getting-started/introduction)
- [Tailwind CSS](https://tailwindcss.com/docs)
- [Application Insights for JavaScript](https://docs.microsoft.com/en-us/azure/azure-monitor/app/javascript)