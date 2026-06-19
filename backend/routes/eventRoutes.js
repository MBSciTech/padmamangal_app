const express = require("express");
const { authMiddleware } = require("../middleware/auth");

function createEventRoutes(eventController) {
    const router = express.Router();
    router.get("/",       authMiddleware, eventController.getEvents);
    router.post("/",      authMiddleware, eventController.createEvent);
    router.delete("/:id", authMiddleware, eventController.deleteEvent);
    return router;
}

module.exports = { createEventRoutes };
