const crypto = require('crypto');
const { ObjectId } = require('mongodb');

const ALGORITHM = 'aes-256-gcm';

function getEncryptionKey() {
    const secret = process.env.VAULT_SECRET || 'default_dev_vault_secret_change_me_in_prod';
    // Derive a 32-byte key from the secret
    return crypto.scryptSync(secret, 'padmamangal_vault_salt', 32);
}

function createVaultController(db) {
    const vaultCollection = db.collection("vault");

    async function uploadDocument(req, res) {
        try {
            const { name, data, type } = req.body;
            if (!name || !data) {
                return res.status(400).json({ message: "Document name and data are required." });
            }

            // Extract the base64 part
            const matches = data.match(/^data:([A-Za-z-+/]+);base64,(.+)$/);
            let buffer;
            let mimeType = 'application/octet-stream';
            
            if (matches && matches.length === 3) {
                mimeType = matches[1];
                buffer = Buffer.from(matches[2], 'base64');
            } else {
                buffer = Buffer.from(data, 'base64');
                // Try to guess mime type from extension
                if (name.endsWith('.pdf')) mimeType = 'application/pdf';
                else if (name.endsWith('.jpg') || name.endsWith('.jpeg')) mimeType = 'image/jpeg';
                else if (name.endsWith('.png')) mimeType = 'image/png';
            }

            const iv = crypto.randomBytes(12);
            const key = getEncryptionKey();
            const cipher = crypto.createCipheriv(ALGORITHM, key, iv);

            let encrypted = cipher.update(buffer);
            encrypted = Buffer.concat([encrypted, cipher.final()]);
            const authTag = cipher.getAuthTag();

            const doc = {
                name,
                type: type || 'file',
                mimeType,
                uploaderId: req.userId,
                size: buffer.length,
                iv: iv.toString('hex'),
                authTag: authTag.toString('hex'),
                encryptedData: encrypted.toString('base64'),
                createdAt: new Date()
            };

            const result = await vaultCollection.insertOne(doc);
            
            // Return metadata without the payload
            return res.status(201).json({
                id: result.insertedId,
                name: doc.name,
                type: doc.type,
                uploaderId: doc.uploaderId,
                size: doc.size,
                createdAt: doc.createdAt
            });

        } catch (error) {
            console.error("Upload vault document error:", error);
            return res.status(500).json({ message: "Server error uploading document." });
        }
    }

    async function getDocuments(req, res) {
        try {
            // Fetch metadata only, exclude heavy encryptedData
            const docs = await vaultCollection.find({}, {
                projection: { iv: 0, authTag: 0, encryptedData: 0 }
            }).sort({ createdAt: -1 }).toArray();

            // Transform _id to id for frontend
            const formattedDocs = docs.map(d => ({
                id: d._id.toString(),
                name: d.name,
                type: d.type,
                uploaderId: d.uploaderId,
                size: d.size,
                createdAt: d.createdAt
            }));

            return res.json(formattedDocs);
        } catch (error) {
            console.error("Get vault documents error:", error);
            return res.status(500).json({ message: "Server error fetching documents." });
        }
    }

    async function downloadDocument(req, res) {
        try {
            const { id } = req.params;
            const doc = await vaultCollection.findOne({ _id: new ObjectId(id) });

            if (!doc) {
                return res.status(404).json({ message: "Document not found." });
            }

            const iv = Buffer.from(doc.iv, 'hex');
            const authTag = Buffer.from(doc.authTag, 'hex');
            const encryptedData = Buffer.from(doc.encryptedData, 'base64');
            const key = getEncryptionKey();

            const decipher = crypto.createDecipheriv(ALGORITHM, key, iv);
            decipher.setAuthTag(authTag);

            let decrypted = decipher.update(encryptedData);
            decrypted = Buffer.concat([decrypted, decipher.final()]);
            
            const dataUri = \`data:\${doc.mimeType};base64,\${decrypted.toString('base64')}\`;

            return res.json({
                id: doc._id.toString(),
                name: doc.name,
                type: doc.type,
                data: dataUri,
                createdAt: doc.createdAt
            });
        } catch (error) {
            console.error("Download vault document error:", error);
            return res.status(500).json({ message: "Server error downloading document. It may have been corrupted or decryption failed." });
        }
    }

    async function deleteDocument(req, res) {
        try {
            const { id } = req.params;
            const result = await vaultCollection.deleteOne({ _id: new ObjectId(id) });
            if (result.deletedCount === 0) {
                return res.status(404).json({ message: "Document not found." });
            }
            return res.json({ message: "Document deleted successfully." });
        } catch (error) {
            console.error("Delete vault document error:", error);
            return res.status(500).json({ message: "Server error deleting document." });
        }
    }

    return {
        uploadDocument,
        getDocuments,
        downloadDocument,
        deleteDocument
    };
}

module.exports = { createVaultController };
