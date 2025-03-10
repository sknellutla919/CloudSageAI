import { SessionProvider } from "next-auth/react";
import "../styles/globals.css";
import "../styles/chat.css"; 

function MyApp({ Component, pageProps: { session, ...pageProps } }) {
  return (
    <SessionProvider session={session}>
      <Component {...pageProps} />
    </SessionProvider>
  );
}

export default MyApp;