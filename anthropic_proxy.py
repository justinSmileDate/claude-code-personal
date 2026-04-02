from fastapi import FastAPI, Request, HTTPException
from fastapi.responses import StreamingResponse, JSONResponse
import httpx
import json
import asyncio

app = FastAPI()
SGLANG_URL = "http://localhost:30000/v1/chat/completions"

@app.post("/v1/messages")
async def anthropic_messages(request: Request):
    body = await request.json()
    
    # 提取请求参数
    messages = body.get("messages", [])
    model = body.get("model", "qwen3")  # 保留原始模型名，或者映射到实际模型
    max_tokens = body.get("max_tokens", 1024)
    temperature = body.get("temperature", 0.7)
    stream = body.get("stream", False)  # Claude Code 默认可能发送 stream=True
    
    # 转换消息格式：Anthropic -> OpenAI
    openai_messages = []
    for msg in messages:
        openai_messages.append({
            "role": msg["role"],
            "content": msg["content"]
        })
    
    openai_payload = {
        "model": model,  # 使用请求中的模型名，或映射到你的实际模型
        "messages": openai_messages,
        "max_tokens": max_tokens,
        "temperature": temperature,
        "stream": stream,
    }
    
    async with httpx.AsyncClient(timeout=60.0) as client:
        if stream:
            # 流式请求：返回 StreamingResponse
            req = client.build_request("POST", SGLANG_URL, json=openai_payload)
            resp = await client.send(req, stream=True)
            
            if resp.status_code != 200:
                # 错误处理：读取错误内容
                error_text = await resp.aread()
                print(f"SGLang 错误: {resp.status_code}, {error_text[:500]}")
                raise HTTPException(status_code=502, detail="上游服务错误")
            
            # 创建一个异步生成器，将 OpenAI SSE 流转换为 Anthropic SSE 流
            async def stream_generator():
                async for line in resp.aiter_lines():
                    if not line.startswith("data:"):
                        continue
                    # 去掉 "data: " 前缀
                    data_str = line[5:].strip()
                    if data_str == "[DONE]":
                        # 发送 Anthropic 的结束标记
                        yield "data: [DONE]\n\n"
                        break
                    try:
                        chunk = json.loads(data_str)
                        # 将 OpenAI 格式的 chunk 转换为 Anthropic 格式
                        anthropic_chunk = {
                            "type": "message",
                            "delta": {
                                "type": "text_delta",
                                "text": chunk["choices"][0]["delta"].get("content", "")
                            },
                            # 可以添加其他字段，如 usage 等
                        }
                        yield f"data: {json.dumps(anthropic_chunk)}\n\n"
                    except json.JSONDecodeError:
                        # 忽略无法解析的行
                        continue
                # 注意：SSE 流结束不需要额外空行
            
            return StreamingResponse(stream_generator(), media_type="text/event-stream")
        else:
            # 非流式请求：等待完整 JSON 响应
            resp = await client.post(SGLANG_URL, json=openai_payload)
            
            if resp.status_code != 200:
                print(f"SGLang 错误状态码: {resp.status_code}")
                print(f"响应内容: {resp.text[:500]}")
                raise HTTPException(status_code=502, detail=f"上游服务错误: {resp.status_code}")
            
            try:
                data = resp.json()
            except Exception as e:
                print(f"JSON 解析失败，原始响应: {resp.text[:500]}")
                raise HTTPException(status_code=502, detail=f"上游服务返回无效 JSON: {str(e)}")
            
            # 转换为 Anthropic 格式（非流式）
            anthropic_response = {
                "id": data.get("id"),
                "type": "message",
                "role": "assistant",
                "content": [{
                    "type": "text",
                    "text": data["choices"][0]["message"]["content"]
                }],
                "model": data.get("model"),
                "stop_reason": "end_turn",
                "usage": {
                    "input_tokens": data["usage"]["prompt_tokens"],
                    "output_tokens": data["usage"]["completion_tokens"]
                }
            }
            return JSONResponse(content=anthropic_response)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8080)
