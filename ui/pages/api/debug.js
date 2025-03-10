export default function handler(req, res) {
    res.status(200).json({
      nextAuthUrl: process.env.NEXTAUTH_URL,
      azureAdClientId: process.env.AZURE_AD_CLIENT_ID ? 'Set' : 'Not set',
      azureAdClientSecret: process.env.AZURE_AD_CLIENT_SECRET ? 'Set' : 'Not set',
      azureAdTenantId: process.env.AZURE_AD_TENANT_ID ? 'Set' : 'Not set',
      nextAuthSecret: process.env.NEXTAUTH_SECRET ? 'Set' : 'Not set'
    });
  }