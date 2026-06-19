const express = require("express");
const { authMiddleware } = require("../middleware/auth");

function createNoticeRoutes(noticeController) {
    const router = express.Router();
    router.get("/",    authMiddleware, noticeController.getNotices);
    router.post("/",   authMiddleware, noticeController.createNotice);
    router.delete("/:id", authMiddleware, noticeController.deleteNotice);
    return router;
}

module.exports = { createNoticeRoutes };
