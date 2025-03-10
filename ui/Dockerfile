FROM node:18-alpine

WORKDIR /app

# Copy everything
COPY . .

# Install dependencies
RUN npm install

# Expose port
EXPOSE 3000

# Start in development mode (simpler for POC)
CMD ["npx", "next", "dev", "-p", "3000", "--hostname", "0.0.0.0"]