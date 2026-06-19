const express = require("express");
const { authMiddleware } = require("../middleware/auth");

function createUserRoutes(userController) {
    const router = express.Router();

    router.get("/profile", authMiddleware, userController.getProfile);
    router.put("/profile", authMiddleware, userController.updateProfile);

    return router;
}

module.exports = { createUserRoutes };
