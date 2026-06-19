const express = require("express");
const { authMiddleware } = require("../middleware/auth");

function createVaultRoutes(vaultController) {
    const router = express.Router();

    // All vault routes require authentication
    router.use(authMiddleware);

    router.get("/", vaultController.getDocuments);
    router.post("/", vaultController.uploadDocument);
    router.get("/:id/download", vaultController.downloadDocument);
    router.delete("/:id", vaultController.deleteDocument);

    return router;
}

module.exports = { createVaultRoutes };
