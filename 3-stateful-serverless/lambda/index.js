const { DynamoDBClient, PutItemCommand } = require("@aws-sdk/client-dynamodb");
const crypto = require("crypto");

// Initialise the client OUTSIDE the handler. 
// This allows the Lambda to reuse the connection on subsequent "warm" requests.
const client = new DynamoDBClient({});

exports.handler = async (event) => {
  const id = crypto.randomUUID();

  const params = {
    TableName: "3-serverless-table",
    Item: {
      id: { S: id },
      timestamp: { S: new Date().toISOString() }
    }
  };

  try {
    await client.send(new PutItemCommand(params));
    
    // Return a success response required by API Gateway
    return {
      statusCode: 200,
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ 
        message: "Successfully inserted item!", 
        id: id 
      }),
    };
  } catch (error) {
    console.error("Error inserting into DynamoDB:", error);
    
    return {
      statusCode: 500,
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ error: "Could not insert item into database." }),
    };
  }
};