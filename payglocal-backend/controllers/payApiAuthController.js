// const axios = require('axios');

// exports.createPaymentLink = async(req,res)=>{
   
//     const {name,email,amount} = req.body;
//     const apiKey = process.env.PAYGLOCAL_API_KEY;
  
//     try {
//       const response = await axios.post(
//         'https://api.uat.payglocal.in/gl/v1/payment-links',
//         {
//             amount: amount,
//             currency: 'INR',
//             customer_details: {
//                 name,
//                 email,
//             },
//             purpose: 'Test Payment',
//             redirect_url: 'https://your-site.com/success', // Replace with your actual redirect URL
//         },
//         {
//             headers: {
//               'Content-Type': 'application/json',
//               'x-gl-auth': apiKey,
//             },
//           }
//       );
//       res.status(200).json({payment_link: response.data.payment_link});
//    } catch (error) {
//     console.error(error.response?.data || error.message);
//     res.status(500).json({ error: 'Failed to create payment link' });
//    }

// };