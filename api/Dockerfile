FROM node:18-alpine

WORKDIR /app

# Copy everything
COPY . .

# Install dependencies
RUN npm install

# Expose port
EXPOSE 3001

# Start in development mode
CMD ["npx", "next", "dev", "-p", "3001", "--hostname", "0.0.0.0"]