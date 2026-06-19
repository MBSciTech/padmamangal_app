const express = require("express");
const { authMiddleware } = require("../middleware/auth");

function createChatRoutes(chatController) {
    const router = express.Router();

    router.get("/", authMiddleware, chatController.getMessages);
    router.post("/", authMiddleware, chatController.sendMessage);
    router.post("/:id/react", authMiddleware, chatController.reactToMessage);
    router.put("/:id/location", authMiddleware, chatController.updateLiveLocation);


    return router;
}

module.exports = { createChatRoutes };
