import express from 'express';
import axios from 'axios';
import cors from 'cors';
import * as jose from 'jose';
import dotenv from 'dotenv';

// Load environment variables
dotenv.config();

const app = express();
const port = 3001;

// Middleware
app.use(cors());
app.use(express.json());

// Load sensitive data from environment variables
const payGlocalPublicKeyPem = process.env.PAYGLOCAL_PUBLIC_KEY;
const merchantPrivateKeyPem = process.env.MERCHANT_PRIVATE_KEY;
const MERCHANT_ID = process.env.MERCHANT_ID;
const KEY_ID = process.env.KEY_ID;

// PayGlocal API endpoint for initiating payment (replace with the actual UAT/production URL)
const PAYGLOCAL_INITIATE_URL = 'https://api.uat.payglocal.in/gl/v1/payments/initiate';

// Validate environment variables
if (!payGlocalPublicKeyPem || !merchantPrivateKeyPem || !MERCHANT_ID || !KEY_ID) {
  console.error('Missing required environment variables');
  process.exit(1);
}

// Helper function to convert PEM to JWK (JSON Web Key)
async function pemToJWK(pem, isPrivate = false) {
  if (isPrivate) {
    const privateKey = await jose.importPKCS8(pem, 'RSA');
    return privateKey;
  } else {
    const publicKey = await jose.importSPKI(pem, 'RSA');
    return publicKey;
  }
}

// JWT-based payment endpoint
app.post('/api/pay/jwt', async (req, res) => {
  try {
    const { merchantTxnId, merchantUniqueId, paymentData, merchantCallBackURL } = req.body;

    // Validate request body
    if (!merchantTxnId || !merchantUniqueId || !paymentData || !paymentData.totalAmount || !paymentData.txnCurrency) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    // Step 1: Prepare the payload (already received from frontend)
    const payload = {
      merchantTxnId,
      merchantUniqueId,
      paymentData,
      merchantCallBackURL,
    };

    // Step 2: Create the JWE token using PayGlocal's public key
    const payGlocalPublicKey = await pemToJWK(payGlocalPublicKeyPem);
    const iat = Date.now(); // Issued at time (current time in milliseconds)
    const exp = iat + 3600 * 1000; // Token expiry (1 hour from now in milliseconds)

    const jweHeader = {
      alg: 'RSA-OAEP-256',
      enc: 'A128CBC-HS256',
      kid: KEY_ID,
      iat,
      exp,
      iss: MERCHANT_ID,
    };

    const jwe = await new jose.EncryptJWT(payload)
      .setProtectedHeader(jweHeader)
      .encrypt(payGlocalPublicKey);

    // Step 3: Create the JWS token using the merchant's private key
    const merchantPrivateKey = await pemToJWK(merchantPrivateKeyPem, true);

    const jws = await new jose.SignJWT({})
      .setProtectedHeader({ alg: 'RS256', typ: 'JWT' })
      .setIssuedAt(iat / 1000) // jose.SignJWT expects seconds for setIssuedAt
      .setExpirationTime(exp / 1000) // jose.SignJWT expects seconds for setExpirationTime
      .setIssuer(MERCHANT_ID)
      .sign(merchantPrivateKey);

    // Step 4: Initiate the payment with PayGlocal
    const response = await axios.post(
      PAYGLOCAL_INITIATE_URL,
      { jwe }, // Send JWE token in body
      {
        headers: {
          'Content-Type': 'application/json',
          'x-gl-token': jws, // Send JWS token in header
        },
      }
    );

    // Step 5: Extract the redirect URL and status URL from the response
    const paymentLink = response.data.redirect_url || 'https://payglocal.in/payment'; // Adjust based on actual response
    const statusLink = response.data.status_url || null; // Adjust based on actual response

    res.status(200).json({
      payment_link: paymentLink,
      status_link: statusLink, // Include status URL for potential future use
    });
  } catch (error) {
    console.error('Error processing JWT payment:', error.message);
    res.status(500).json({ error: error.message || 'Failed to initiate payment' });
  }
});

// Callback endpoint to handle PayGlocal's response
app.post('/callback', (req, res) => {
  try {
    const xGlToken = req.headers['x-gl-token'];

    if (!xGlToken) {
      return res.status(400).json({ error: 'Missing x-gl-token in headers' });
    }

    // Step 6: Decode the x-gl-token (expected format: header.payload.signature)
    const tokenParts = xGlToken.split('.');
    if (tokenParts.length !== 3) {
      return res.status(400).json({ error: 'Invalid x-gl-token format' });
    }

    // Extract and decode the payload (middle part)
    const payloadBase64 = tokenParts[1];
    const decodedPayload = Buffer.from(payloadBase64, 'base64').toString('utf8');
    const parsedPayload = JSON.parse(decodedPayload);

    console.log('Decoded callback payload:', parsedPayload);

    // Respond to PayGlocal (acknowledgement)
    res.status(200).json({ status: 'received' });

    // TODO: Process the callback data (e.g., update transaction status in your database)
  } catch (error) {
    console.error('Error processing callback:', error.message);
    res.status(500).json({ error: 'Failed to process callback' });
  }
});

// Start the server
app.listen(port, () => {
  console.log(`JWT Server running on http://localhost:${port}`);
});