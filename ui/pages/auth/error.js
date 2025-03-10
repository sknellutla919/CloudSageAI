import React from 'react';
import { useRouter } from 'next/router';
import { Button } from '../../components';

export default function ErrorPage() {
  const router = useRouter();
  const { error } = router.query;

  console.log("Auth error page loaded", { error, query: router.query });

  return (
    <div className="flex flex-col items-center justify-center h-screen p-4">
      <div className="bg-white p-6 rounded-lg shadow-lg max-w-md w-full">
        <h1 className="text-red-600 text-2xl font-bold mb-4">Authentication Error</h1>
        <p className="text-gray-700 mb-4">
          There was a problem signing you in.
        </p>
        <pre className="bg-gray-100 p-4 rounded mb-4 overflow-auto text-sm">
          {error ? `Error: ${error}` : 'No error details provided'}
          {JSON.stringify(router.query, null, 2)}
        </pre>
        <div className="flex justify-between">
          <Button onClick={() => router.push('/')}>
            Try Again
          </Button>
        </div>
      </div>
    </div>
  );
}