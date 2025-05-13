import fs from 'fs';
import path from 'path';

function convertPemToEnvFormat(filePath, envVarName) {
  const pemContent = fs.readFileSync(filePath, 'utf8');
  const escaped = pemContent.replace(/\n/g, '\\n');
  console.log(`${envVarName}="${escaped}"\n`);
}

// Update the paths to point to your correct file locations
convertPemToEnvFormat('./keys/kid-WmfYgXuUh3qQvyuw_payglocal_mid.pem', 'PAYGLOCAL_PUBLIC_KEY');
convertPemToEnvFormat('./keys/kid-vU6e8l6bWtXK8oOK_testnewgcc26.pem', 'MERCHANT_PRIVATE_KEY');
