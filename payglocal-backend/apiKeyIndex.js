// import express from 'express';
// import axios from 'axios';
// import cors from 'cors';
// import * as jose from 'jose';
// import dotenv from 'dotenv';
// import crypto from 'crypto';

// // Load environment variables
// dotenv.config();

// const app = express();
// const port = process.env.PORT || 3000;

// // Middleware
// app.use(cors());
// app.use(express.json());

// // Load sensitive data
// const {
//   API_KEY,
//   PAYGLOCAL_PUBLIC_KEY,
//   MERCHANT_PRIVATE_KEY,
//   MERCHANT_ID,
//   PUBLIC_KEY_ID,
//   PRIVATE_KEY_ID,
//   PAYGLOCAL_INITIATE_URL // Added
// } = process.env;

// // Validate environment variables
// if (!API_KEY || !PAYGLOCAL_PUBLIC_KEY || !MERCHANT_PRIVATE_KEY || !MERCHANT_ID || !PUBLIC_KEY_ID || !PRIVATE_KEY_ID || !PAYGLOCAL_INITIATE_URL) {
//   console.error('Missing required environment variables');
//   process.exit(1);
// }

// async function pemToKey(pem, isPrivate = false) {
//   return isPrivate
//     ? await jose.importPKCS8(pem, 'RS256')
//     : await jose.importSPKI(pem, 'RSA');
// }

// // API Key flow
// app.post('/api/pay/jwt', async (req, res) => {
//   try {
//     const { merchantTxnId, merchantUniqueId, paymentData, merchantCallBackURL } = req.body;

//     // Validate input
//     if (
//       !merchantTxnId ||
//       !merchantUniqueId ||
//       !paymentData ||
//       !paymentData.totalAmount ||
//       !paymentData.txnCurrency ||
//       !paymentData.billingData ||
//       !paymentData.billingData.firstName ||
//       !paymentData.billingData.lastName ||
//       !paymentData.billingData.emailId ||
//       !merchantCallBackURL
//     ) {
//       return res.status(400).json({ error: 'Missing required fields in request body' });
//     }

//     // Step 1: Prepare payload
//     const fullPaymentData = {
//       ...paymentData,
//       totalAmount: parseFloat(paymentData.totalAmount),
//       txnCurrency: 'INR',
//       billingData: {
//         firstName: paymentData.billingData.firstName,
//         lastName: paymentData.billingData.lastName,
//         emailId: paymentData.billingData.emailId,
//         addressLine1: paymentData.billingData.addressLine1 || '123 Main Street',
//         addressLine2: paymentData.billingData.addressLine2 || 'Apt 4B',
//         city: paymentData.billingData.city || 'Mumbai',
//         state: paymentData.billingData.state || 'MH',
//         country: paymentData.billingData.country || 'IN',
//         zipCode: paymentData.billingData.zipCode || '400001',
//         phoneNumber: paymentData.billingData.phoneNumber || '9999999999',
//         phoneNumberCountryCode: paymentData.billingData.phoneNumberCountryCode || '+91',
//       },
//     };


//     const privateKey = await pemToKey(MERCHANT_PRIVATE_KEY, true);
//     const publicKey = await pemToKey(PAYGLOCAL_PUBLIC_KEY, false);
//     const iat = Math.floor(Date.now() / 1000);
//     const exp = iat + 300; // expires in 5 minutes


// //     const payload = {                                          more refind not working
// //       merchantTxnId,
// //       merchantUniqueId,
// //       paymentData: fullPaymentData,
// //       merchantCallBackURL,
// //       paymentType: "SALE",
// //       orderDescription: `Payment for transaction ${merchantTxnId}`,
// //       merchantRedirectURL: "https://ff6d-31-13-189-18.ngrok-free.app/redirect"
// //     };
    
// //     const stringifiedPayload = JSON.stringify(payload);
    
// //     console.log('Step 1 - Payload:', payload);


// //     // for jws
// //     const digestBuffer = crypto.createHash('sha256').update(stringifiedPayload).digest();
// //     const digest = digestBuffer.toString('base64');


// // // Step 2: Create JWS Token (signed with merchant private key)
// // const jws = await new jose.SignJWT({
// //   digest: digest,
// //   digestAlgorithm: "SHA-256",
// // })
// // .setProtectedHeader({
// //     alg: 'RS256',
// //     kid: PRIVATE_KEY_ID,
// //     'x-gl-enc': 'true',
// //     'is-digest': 'true',
// //     'issued-by': MERCHANT_ID,
// //   })
// //   .setIssuedAt(iat)
// //   .setExpirationTime(exp)
// //   .sign(privateKey);

// // console.log('Step 2 - JWS created:', jws);

// const payload = {
//   merchantTxnId,
//   merchantUniqueId,
//   paymentData: fullPaymentData,
//   merchantCallBackURL,
//   paymentType: 'SALE',
//   orderDescription: `Payment for transaction ${merchantTxnId}`,
//   merchantRedirectURL: 'https://ff6d-31-13-189-18.ngrok-free.app/redirect',
// };

// console.log('Step 1 - Payload:', payload);

// // Step 2: Create JWS from payload

// // const jws = await new jose.SignJWT(payload)
// //   .setProtectedHeader({
// //     alg: 'RS256',
// //     kid: PRIVATE_KEY_ID,
// //     'x-gl-enc': true,
// //     'is-digest': false,
// //     'issued-by': MERCHANT_ID,
// //   })
// //   .setIssuedAt(iat)
// //   .setExpirationTime(exp)
// //   .sign(privateKey);

// const jws = await new jose.SignJWT(payload)
// .setProtectedHeader({
// alg: 'RS256',
// kid: PUBLIC_KEY_ID, // Corrected to use the public key ID
// 'x-gl-enc': true,
// 'is-digest': false,
// 'issued-by': MERCHANT_ID,
// })
// .setIssuedAt(iat)
// .setExpirationTime(exp)
// .sign(privateKey);


// // Step 3: Create JWE Token (encrypt payload with Payglocal's public key)

// const jwe = await new jose.EncryptJWT(stringifiedPayload) // correct
//   .setProtectedHeader({
//     alg: 'RSA-OAEP-256',
//     enc: 'A128CBC-HS256',
//     // 'key-id': PUBLIC_KEY_ID,
//     'kid': PUBLIC_KEY_ID,    
//     'issued-by': MERCHANT_ID,
//   })
//   .setIssuedAt(iat)
//   .setExpirationTime(exp)
//   .encrypt(publicKey);

//     const { redirect_url, status_url } = response.data;
//     res.status(200).json({ payment_link: redirect_url, status_link: status_url });

//     console.log('Step 3 - JWE created:', jwe);


//     console.log('Step 4 - Sending request to:', PAYGLOCAL_INITIATE_URL);

//     try {
//       const response = await axios.post(
//         PAYGLOCAL_INITIATE_URL,
//         { token: jwe },
//         {
//           headers: {
//             'Content-Type': 'application/json',
//             Authorization: `Bearer ${jws}`,
//             'x-gl-merchantId': MERCHANT_ID,
//           },
//         }
//       );
    
//       const { redirect_url, status_url } = response.data;
//       res.status(200).json({ payment_link: redirect_url, status_link: status_url });
//     } catch (error) {
//       if (axios.isAxiosError(error)) {
//         console.error('Axios error:', error.message);
//         if (error.response) {
//           console.error('Status code:', error.response.status);
//           console.error('Response data:', JSON.stringify(error.response.data, null, 2));
//         } else if (error.request) {
//           console.error('No response received:', error.request);
//         } else {
//           console.error('Error setting up request:', error.message);
//         }
//       } else {
//         console.error('Unexpected error:', error);
//       }
    
//       res.status(500).json({
//         error: 'Failed to initiate payment',
//         details: error.message,
//       });
//     }
  


//   } catch (error) {
//     console.error('Response status:', error.response?.status);
//     console.error('Response body:', error.response?.data);
//     console.error('Unexpected error:', error.message);
//     res.status(500).json({ error: error.response?.data?.message || error.message });
//   }
// });


// // Callback handler
// app.post('/callback', (req, res) => {
//   try {
//     const xGlToken = req.headers['x-gl-token'];
//     if (!xGlToken) {
//       return res.status(400).json({ error: 'Missing x-gl-token' });
//     }

//     const parts = xGlToken.split('.');
//     if (parts.length !== 3) {
//       return res.status(400).json({ error: 'Invalid JWT format' });
//     }

//     const decodedPayload = Buffer.from(parts[1], 'base64').toString('utf8');
//     console.log('Callback payload:', JSON.parse(decodedPayload));

//     res.status(200).json({ status: 'received' });
//   } catch (error) {
//     console.error('Callback Error:', error.message);
//     res.status(500).json({ error: 'Callback handling failed' });
//   }
// });

// app.listen(port, () => {
//   console.log(`Server running on http://localhost:${port}`);
// });

import express from 'express';
import axios from 'axios';
import cors from 'cors';
import * as jose from 'jose';
import dotenv from 'dotenv';
import crypto from 'crypto';

// Load environment variables
dotenv.config();

const app = express();
const port = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

// Load sensitive data
const {
  API_KEY,
  PAYGLOCAL_PUBLIC_KEY,
  MERCHANT_PRIVATE_KEY,
  MERCHANT_ID,
  PUBLIC_KEY_ID,
  PRIVATE_KEY_ID,
  PAYGLOCAL_INITIATE_URL // Added
  
} = process.env;

// Validate environment variables
if (!API_KEY || !PAYGLOCAL_PUBLIC_KEY || !MERCHANT_PRIVATE_KEY || !MERCHANT_ID || !PUBLIC_KEY_ID || !PRIVATE_KEY_ID || !PAYGLOCAL_INITIATE_URL) {
  console.error('Missing required environment variables');
  process.exit(1);
}

async function pemToKey(pem, isPrivate = false) {
  return isPrivate
    ? await jose.importPKCS8(pem, 'RS256')
    : await jose.importSPKI(pem, 'RSA');
}

// API Key flow
app.post('/api/pay/jwt', async (req, res) => {
  try {
    const { merchantTxnId, merchantUniqueId, paymentData, merchantCallBackURL } = req.body;

    // Validate input
    if (
      !merchantTxnId ||
      !merchantUniqueId ||
      !paymentData ||
      !paymentData.totalAmount ||
      !paymentData.txnCurrency ||
      !paymentData.billingData ||
      !paymentData.billingData.firstName ||
      !paymentData.billingData.lastName ||
      !paymentData.billingData.emailId ||
      !merchantCallBackURL
    ) {
      return res.status(400).json({ error: 'Missing required fields in request body' });
    }

    // Step 1: Prepare payload
    const fullPaymentData = {
      ...paymentData,
      totalAmount: parseFloat(paymentData.totalAmount),
      txnCurrency: 'INR',
      billingData: {
        firstName: paymentData.billingData.firstName,
        lastName: paymentData.billingData.lastName,
        emailId: paymentData.billingData.emailId,
        addressLine1: paymentData.billingData.addressLine1 || '123 Main Street',
        addressLine2: paymentData.billingData.addressLine2 || 'Apt 4B',
        city: paymentData.billingData.city || 'Mumbai',
        state: paymentData.billingData.state || 'MH',
        country: paymentData.billingData.country || 'IN',
        zipCode: paymentData.billingData.zipCode || '400001',
        phoneNumber: paymentData.billingData.phoneNumber || '9999999999',
        phoneNumberCountryCode: paymentData.billingData.phoneNumberCountryCode || '+91',
      },
    };

    const payload = {
      merchantTxnId,
      merchantUniqueId,
      paymentData: fullPaymentData,
      merchantCallBackURL,
      paymentType: 'SALE',
      orderDescription: 'Payment for transaction ${merchantTxnId}',
      merchantRedirectURL: 'https://ff6d-31-13-189-18.ngrok-free.app/redirect',
    };

    console.log('Step 1 - Payload:', payload);

    // Step 2: Create JWS from payload
    const privateKey = await pemToKey(MERCHANT_PRIVATE_KEY, true);
    const iat = Math.floor(Date.now() / 1000);
    const exp = iat + 300; // expires in 5 minutes

    // const jws = await new jose.SignJWT(payload)
    //   .setProtectedHeader({
    //     alg: 'RS256',
    //     kid: PRIVATE_KEY_ID,
    //     'x-gl-enc': true,
    //     'is-digest': false,
    //     'issued-by': MERCHANT_ID,
    //   })
    //   .setIssuedAt(iat)
    //   .setExpirationTime(exp)
    //   .sign(privateKey);

    const jws = await new jose.SignJWT(payload)
  .setProtectedHeader({
    alg: 'RS256',
    kid: PUBLIC_KEY_ID, // Corrected to use the public key ID
    'x-gl-enc': true,
    'is-digest': false,
    'issued-by': MERCHANT_ID,
  })
  .setIssuedAt(iat)
  .setExpirationTime(exp)
  .sign(privateKey);


    console.log('Step 2 - JWS created:', jws);

    // Step 3: Encrypt JWS into JWE
    const payloadStr = JSON.stringify(payload);

// Step 2: Create JWE with the stringified JSON request payload
const publicKey = await pemToKey(PAYGLOCAL_PUBLIC_KEY, false);

// const jwe = await new jose.EncryptJWT({ payload: payloadStr }) // Encrypt the stringified payload
const jwe = await new jose.EncryptJWT({ payload: payloadStr }) // Encrypt the stringified payload
  .setProtectedHeader({
    alg: 'RSA-OAEP-256',
    enc: 'A128CBC-HS256',
    'key-id': PUBLIC_KEY_ID, // Use key-id as per PayGlocal
    iat,
    exp,
    'issued-by': MERCHANT_ID,
  })
  .encrypt(publicKey);


console.log('JWE created:', jwe);
    // const publicKey = await pemToKey(PAYGLOCAL_PUBLIC_KEY, false);
    // const jwe = await new jose.EncryptJWT({ data: jws })
    //   .setProtectedHeader({
    //     alg: 'RSA-OAEP-256',
    //     enc: 'A128CBC-HS256',
    //     kid: PUBLIC_KEY_ID,
    //   })
    //   .setIssuedAt(iat)
    //   .setExpirationTime(exp)
    //   .setIssuer(MERCHANT_ID)
    //   .encrypt(publicKey);

    // console.log('Step 3 - JWE created:', jwe);

    // Step 4: Make request to PayGlocal

    const { redirect_url, status_url } = response.data;
    res.status(200).json({ payment_link: redirect_url, status_link: status_url });

    console.log('Step 4 - Sending request to:', PAYGLOCAL_INITIATE_URL);
    try {
            const response = await axios.post(
              PAYGLOCAL_INITIATE_URL,
              { token: jwe },
              {
                headers: {
                  'Content-Type': 'application/json',
                  Authorization: `Bearer ${jws}`,
                  'x-gl-merchantId': MERCHANT_ID,
                },
              }
            );
          
            const { redirect_url, status_url } = response.data;
            res.status(200).json({ payment_link: redirect_url, status_link: status_url });
          } catch (error) {
            if (axios.isAxiosError(error)) {
              console.error('Axios error:', error.message);
              if (error.response) {
                console.error('Status code:', error.response.status);
                console.error('Response data:', JSON.stringify(error.response.data, null, 2));
              } else if (error.request) {
                console.error('No response received:', error.request);
              } else {
                console.error('Error setting up request:', error.message);
              }
            } else {
              console.error('Unexpected error:', error);
            }
          
            res.status(500).json({
              error: 'Failed to initiate payment',
              details: error.message,
            });
          }
        
      
      
        } catch (error) {
          console.error('Response status:', error.response?.status);
          console.error('Response body:', error.response?.data);
          console.error('Unexpected error:', error.message);
          res.status(500).json({ error: error.response?.data?.message || error.message });
        }
      });
      
      
      // Callback handler
      app.post('/callback', (req, res) => {
        try {
          const xGlToken = req.headers['x-gl-token'];
          if (!xGlToken) {
            return res.status(400).json({ error: 'Missing x-gl-token' });
          }
      
          const parts = xGlToken.split('.');
          if (parts.length !== 3) {
            return res.status(400).json({ error: 'Invalid JWT format' });
          }
      
          const decodedPayload = Buffer.from(parts[1], 'base64').toString('utf8');
          console.log('Callback payload:', JSON.parse(decodedPayload));
      
          res.status(200).json({ status: 'received' });
        } catch (error) {
          console.error('Callback Error:', error.message);
          res.status(500).json({ error: 'Callback handling failed' });
        }
      });
      
      app.listen(port, () => {
        console.log(`Server running on http://localhost:${port}`);
      });