"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.handler = void 0;
const handler = async (event) => {
    console.log("Received event:", JSON.stringify(event, null, 2));
    return {
        statusCode: 200,
        body: JSON.stringify({ message: "Hello from Lambda!" })
    };
};
exports.handler = handler;
