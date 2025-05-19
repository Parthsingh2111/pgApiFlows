import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const basePath = path.join(__dirname, 'keys');
const envFilePath = path.join(__dirname, '.env');

let envContent = '';

envContent += convertPemToEnvFormat(path.join(basePath, 'kId-yLtRky48X2HqW30k_payglocal_mid.pem'), 'PAYGLOCAL_PUBLIC_KEY');
envContent += convertPemToEnvFormat(path.join(basePath, 'kId-vU6e8l6bWtXK8oOK_testnewgcc26.pem'), 'MERCHANT_PRIVATE_KEY');

fs.writeFileSync(envFilePath, envContent.trim() + '\n');
console.log('.env file created or updated with PEM keys.');

function convertPemToEnvFormat(filePath, envVarName) {
  try {
    const pemContent = fs.readFileSync(filePath, 'utf8');
    const cleanedPem = pemContent
      .replace(/-----BEGIN (PUBLIC|PRIVATE) KEY-----/, '')
      .replace(/-----END (PUBLIC|PRIVATE) KEY-----/, '')
      .replace(/\n/g, '')
      .trim();
    return `${envVarName}="${cleanedPem}"\n`;
  } catch (error) {
    console.error(`Error reading PEM file ${filePath}: ${error.message}`);
    process.exit(1);
  }
}
