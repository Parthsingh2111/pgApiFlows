
import express from 'express';
import axios from 'axios';
import cors from 'cors';
import * as jose from 'jose'; // Keep for other jose functions
import { CompactEncrypt, SignJWT } from 'jose'; // Explicit imports for CompactEncrypt and SignJWT
import dotenv from 'dotenv';
import crypto from 'crypto';
import fs from 'fs';


///  both combined  ///

// Load environment variables from .env file so we dont write secrets in the code
dotenv.config();
const port = process.env.PORT || 3000;

// some middleware to handle cors and json request body
const app = express();

app.listen(port, () => {
  console.log(`Server is running on http://localhost:${port}`);
});


app.use(cors());
app.use(express.json());

// Grabing all important config from env file
const {
  API_KEY,
  PAYGLOCAL_PUBLIC_KEY,
  MERCHANT_PRIVATE_KEY,
  MERCHANT_ID,
  PUBLIC_KEY_ID,
  PRIVATE_KEY_ID,
  PAYGLOCAL_INITIATE_URL,
} = process.env;

// Make sure we have all secret info, if not then stop the app
if (!API_KEY || !PAYGLOCAL_PUBLIC_KEY || !MERCHANT_PRIVATE_KEY || !MERCHANT_ID || !PUBLIC_KEY_ID || !PRIVATE_KEY_ID || !PAYGLOCAL_INITIATE_URL) {
  console.error('Missing required environment variables');
  process.exit(1);
}

// sending the actual request to payglocal to get the payment link




const CALLBACK_URL = 'https://api.uat.payglocal.in/gl/v1/payments/merchantCallback';

app.post('/api/pay/apikey', async (req, res) => {
  try {
    // Destructure the required fields from the request body
    const { merchantTxnId, paymentData, merchantCallbackURL } = req.body;

    // Check if all required fields are present
    if (!merchantTxnId || !paymentData || !paymentData.totalAmount || !paymentData.txnCurrency || !paymentData.billingData || !paymentData.billingData.emailId || !merchantCallbackURL) {
      return res.status(400).json({ error: 'Missing required fields: merchantTxnId, paymentData, or merchantCallbackURL' });
    }

    // Construct the payload to send to PayGlocal
    const payload = {
      merchantTxnId,  // Received from the frontend
      paymentData,  // Received from the frontend
      merchantCallbackURL,  // Received from the frontend
    };

    console.log('Sending to PayGlocal:', payload);

    // Send the payload to PayGlocal
    const response = await axios.post(
      'https://api.uat.payglocal.in/gl/v1/payments/initiate/paycollect',
      payload,
      {
        headers: {
          'x-gl-auth': API_KEY,  // Your API key for authentication
          'Content-Type': 'application/json',
        },
      }
    );

    console.log('Payglocal response:', response.data);


    // const { redirect_url, status_url } = response.data;

    const redirect_url =
      response.data?.data?.redirectUrl ||
      response.data?.redirect_url ||
      response.data?.payment_link;

    const status_url =
      response.data?.data?.statusUrl ||
      response.data?.status_url ||
      null;

    if (!redirect_url) {
      console.error('No redirect_url found in:', response.data);
      return res.status(502).json({ error: 'No payment link received' });
    }

    res.status(200).json({
      payment_link: redirect_url,
      status_link: status_url,
    });

  } catch (error) {
    if (axios.isAxiosError(error)) {
      console.error('Payglocal Error:', error.response?.data || error.message);
      return res.status(error.response?.status || 500).json({
        error: 'Payment initiation failed',
        details: error.response?.data || error.message,
      });
    }

    console.error('Server Error:', error.message);
    res.status(500).json({
      error: 'Unexpected server error',
      details: error.message,
    });
  }
});



async function pemToKey(pem, isPrivate = false) {
  return isPrivate
    ? await jose.importPKCS8(pem, 'RS256') // JWS
    : await jose.importSPKI(pem, 'RSA-OAEP-256'); // JWE
}


app.post('/api/pay/jwt', async (req, res) => {
  try {
    // const { merchantTxnId,paymentData, merchantCallbackURL } = req.body;
    const { merchantTxnId, merchantUniqueId, paymentData, merchantCallbackURL } = req.body;
    if (
      !merchantTxnId ||
      !paymentData ||
      !merchantUniqueId ||
      !paymentData.totalAmount ||
      !paymentData.txnCurrency ||
      !paymentData.billingData ||
      !paymentData.billingData.emailId ||
      !merchantCallbackURL
    ) {
      return res.status(400).json({ error: 'Missing required fields: merchantTxnId,merchantUniqueId,paymentData, or merchantCallbackURL' });
    }

    const payload = {
      merchantTxnId,
      paymentData,
      merchantCallbackURL,
    };

    console.log('Payload:', JSON.stringify(payload, null, 2));
    console.log('Environment Variables:', {
      MERCHANT_ID: process.env.MERCHANT_ID,
      PUBLIC_KEY_ID: process.env.PUBLIC_KEY_ID,
      PRIVATE_KEY_ID: process.env.PRIVATE_KEY_ID,
      API_KEY: process.env.API_KEY ? 'Set' : 'Not Set',
    });

    // Generate iat and exp
    let iat = Date.now();
    let exp = iat + 300000; // 5 minutes

    // Encrypt payload into JWE
    const payloadStr = JSON.stringify(payload);
    const publicKey = await pemToKey(process.env.PAYGLOCAL_PUBLIC_KEY, false);

    const jwe = await new jose.CompactEncrypt(new TextEncoder().encode(payloadStr))
      .setProtectedHeader({
        alg: 'RSA-OAEP-256',
        enc: 'A128CBC-HS256',
        iat: iat.toString(), // String for consistency
        exp: 300000, // Number, not string
        kid: process.env.PUBLIC_KEY_ID,
        'issued-by': process.env.MERCHANT_ID,
      })
      .encrypt(publicKey);

    console.log('JWE:', jwe);
    console.log('JWE Header:', JSON.parse(Buffer.from(jwe.split('.')[0], 'base64').toString()));

    // Sign JWE into JWS
    // iat = Date.now();
    const jwsIat = Date.now()
    exp = 300000;

    const privateKey = await pemToKey(process.env.MERCHANT_PRIVATE_KEY, true);
    const digestObject = {
      digest: crypto.createHash('sha256').update(jwe).digest('base64'),
      digestAlgorithm: 'SHA-256',
      exp: exp, // Number, not string
      iat: iat.toString(), // String for consistency
    };

    const jws = await new jose.CompactSign(new TextEncoder().encode(JSON.stringify(digestObject)))
      .setProtectedHeader({
        'issued-by': process.env.MERCHANT_ID,
        alg: 'RS256',
        kid: process.env.PRIVATE_KEY_ID,
        'x-gl-merchantId': process.env.MERCHANT_ID,
        'x-gl-enc': 'true',
        'is-digested': 'true',
      })
      .sign(privateKey);

    console.log('JWS:', jws);
    console.log('JWS Header:', JSON.parse(Buffer.from(jws.split('.')[0], 'base64').toString()));

    // Send to PayGlocal
    const pgResponse = await axios.post(
      'https://api.uat.payglocal.in/gl/v1/payments/initiate/paycollect',
      jwe, // Raw JWE string
      {
        headers: {
          'Content-Type': 'text/plain',
          // 'Content-Type': 'application/json',
          'x-gl-token-external': jws,
        },
      }
    );

    console.log('PayGlocal Response:', pgResponse.data);

    const redirect_url =
      pgResponse.data?.data?.redirectUrl ||
      pgResponse.data?.redirect_url ||
      pgResponse.data?.payment_link;

    const status_url =
      pgResponse.data?.data?.statusUrl ||
      pgResponse.data?.status_url ||
      null;

    if (!redirect_url) {
      console.error('No redirect_url found in:', pgResponse.data);
      return res.status(502).json({ error: 'No payment link received' });
    }

    const statusUrl = pgResponse.data?.data?.statusUrl || pgResponse.data?.status_url || null;

    let gid = null;
    if (statusUrl) {
      const match = statusUrl.match(/\/payments\/([^/]+)\/status/);
      gid = match ? match[1] : null;
    }

    res.status(200).json({
      payment_link: redirect_url,
      // status_link: status_url,
      gid: gid,
    });
  } catch (error) {
    if (axios.isAxiosError(error)) {
      console.error('Payglocal Error Response:', JSON.stringify(error.response?.data, null, 2));
      console.error('Status:', error.response?.status);
      console.error('Headers:', error.response?.headers);
      return res.status(error.response?.status || 500).json({
        error: 'Payment initiation failed',
        details: error.response?.data || error.message,
      });
    }

    console.error('Error in /api/pay/jwt:', error.message || error);
    return res.status(500).json({
      error: 'Internal server error',
      details: error.message,
    });
  }


});


app.get('/api/status', async (req, res) => {
  console.log('>>> /api/status endpoint hit');
  const gid = req.query.gid;
  console.log('Received gid:', gid);

  if (!gid) {
    console.error('Missing gid query parameter');
    return res.status(400).json({ error: 'Missing gid query parameter' });
  }

  const statusUrl = `https://api.uat.payglocal.in/gl/v1/payments/${gid}/status`;
  const payloadPath = `/gl/v1/payments/${gid}/status`;

  try {
    
    const iat = Date.now()
    const exp = 300000;

    const privateKey = await pemToKey(process.env.MERCHANT_PRIVATE_KEY, true);
    const digestObject = {
      digest: crypto.createHash('sha256').update(payloadPath).digest('base64'),
      digestAlgorithm: 'SHA-256',
      exp: exp, // Number, not string
      iat: iat.toString(), // String for consistency
    };


    const Payloadjws = await new jose.SignJWT(digestObject)
      .setProtectedHeader({
        'issued-by': process.env.MERCHANT_ID,
        alg: 'RS256',
        kid: process.env.PRIVATE_KEY_ID,
        'x-gl-merchantId': process.env.MERCHANT_ID,
        'x-gl-enc': 'true',
        'is-digested': 'true',
      })
      .sign(privateKey);

    console.log('Payload JWS:', Payloadjws);

    const response = await axios.get(statusUrl, {
      headers: {
        'x-gl-token-external': Payloadjws,
      },
    });
    console.log('PayGlocal status response:', response.data);
   
    res.status(200).json({
      status: response.data.status, // e.g., "Successfull"
      gid: response.data.gid,
      message: response.data.message
    });


  } catch (err) {
    if (err.response) {
      console.error('PayGlocal error:', err.response.status, err.response.data);
      return res.status(err.response.status || 500).json({
        error: 'PayGlocal API call failed',
        status: err.response.status,
        body: err.response.data.toString().substring(0, 200), // Limit for logging
      });
    } else {
      console.error('Request failed:', err.message);
      return res.status(500).json({
        error: 'Failed to fetch payment status',
        details: err.message,
      });
    }
  }
});



//refund endpoint

app.post('/api/refund', async (req, res) => {
  console.log('>>> /api/refund endpoint hit');
  const { gid, refundType, paymentData } = req.body;
  console.log('Received refund request:', { gid, refundType, paymentData });

  if (!gid) {
    console.error('Missing gid');
    return res.status(400).json({ error: 'Missing gid' });
  }

  if (!refundType || (refundType !== 'F' && refundType !== 'P')) {
    console.error('Invalid or missing refundType');
    return res.status(400).json({ error: 'Invalid or missing refundType (must be F or P)' });
  }

  if (refundType === 'P' && (!paymentData || !paymentData.totalAmount)) {
    console.error('Missing paymentData.totalAmount for partial refund');
    return res.status(400).json({ error: 'Missing paymentData.totalAmount for partial refund' });
  }

  const merchantTxnId = '23AEE8CB6B62EE2AF06'; // Hardcoded
  const refundUrl = `https://api.uat.payglocal.in/gl/v1/payments/${gid}/refund`;

  try {
    // Prepare payload
    const payload = refundType === 'F'
      ? { merchantTxnId, refundType: 'F' }
      : {
          merchantTxnId,
          refundType: 'P',
          paymentData: { totalAmount: paymentData.totalAmount },
        };

    // Generate JWE
    let iat = Date.now();
    let exp = iat + 300000; // 5 minutes

    const payloadStr = JSON.stringify(payload);
    const publicKey = await pemToKey(process.env.PAYGLOCAL_PUBLIC_KEY, false);

    const jwe = await new jose.CompactEncrypt(new TextEncoder().encode(payloadStr))
      .setProtectedHeader({
        alg: 'RSA-OAEP-256',
        enc: 'A128CBC-HS256',
        iat: iat.toString(),
        exp: exp,
        kid: process.env.PUBLIC_KEY_ID,
        'issued-by': process.env.MERCHANT_ID,
      })
      .encrypt(publicKey);

    console.log('JWE:', jwe);
    console.log('JWE Header:', JSON.parse(Buffer.from(jwe.split('.')[0], 'base64').toString()));

    // Generate JWS
    const jwsIat = Date.now();
    exp = jwsIat + 300000;

    const privateKey = await pemToKey(process.env.MERCHANT_PRIVATE_KEY, true);
    const digestObject = {
      digest: crypto.createHash('sha256').update(jwe).digest('base64'),
      digestAlgorithm: 'SHA-256',
      exp: exp,
      iat: jwsIat.toString(),
    };

    const jws = await new jose.CompactSign(new TextEncoder().encode(JSON.stringify(digestObject)))
      .setProtectedHeader({
        'issued-by': process.env.MERCHANT_ID,
        alg: 'RS256',
        kid: process.env.PRIVATE_KEY_ID,
        'x-gl-merchantId': process.env.MERCHANT_ID,
        'x-gl-enc': 'true',
        'is-digested': 'true',
      })
      .sign(privateKey);

    console.log('JWS:', jws);
    console.log('JWS Header:', JSON.parse(Buffer.from(jws.split('.')[0], 'base64').toString()));

    // Send to PayGlocal
    const pgResponse = await axios.post(refundUrl, jwe, {
      headers: {
        'Content-Type': 'text/plain',
        'x-gl-token-external': jws,
      },
    });

    console.log('PayGlocal refund response:', pgResponse.data);

    return res.status(200).json({
      status: pgResponse.data.status || 'INITIATED',
      gid: pgResponse.data.gid || gid,
      message: pgResponse.data.message || 'Refund request processed',
      refundId: pgResponse.data.refundId || '',
    });
  } catch (err) {
    if (err.response) {
      console.error('PayGlocal error:', err.response.status, err.response.data);
      return res.status(err.response.status || 500).json({
        error: 'PayGlocal API call failed',
        status: err.response.status,
        message: err.response.data.message || 'Refund request failed',
      });
    } else {
      console.error('Request failed:', err.message);
      return res.status(500).json({
        error: 'Failed to process refund',
        message: err.message,
      });
    }
  }
});