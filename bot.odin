package main

import "core:os"
import "core:fmt"
import "core:time"
import "core:encoding/json"

import http "external/odin-http"
import "external/odin-http/client"
import dotenv "external/odin-dotenv"

Request_Error :: union {
    client.Error,
    client.Body_Error,
    json.Marshal_Error
}

Send_Message_Body :: struct {
    content: string,
    embeds: []Discord_Embed
}

Discord_Message :: struct {
    id: string,
    channel_id: string,
}

Discord_Embed :: struct {
    title: string,
    description: string,
    color: int
}

main :: proc() {
    dotenv.load(".env")

    embeds := []Discord_Embed{Discord_Embed{"Title", "Description", 0xff00ff}}
    send_message("1388197790567370996", "This is a message with an embed", embeds)

    msg_obj, err := send_message("1388197790567370996", "This message will self-destruct in 5 second(s)")
    if err != nil {
        return
    }

    i := 5
    for i > 0 {
        edit_message(msg_obj.channel_id, msg_obj.id, fmt.aprintf("This message will self-destruct in %v second(s)", i))
        time.sleep(time.Second)
        i -= 1
    }

    delete_message(msg_obj.channel_id, msg_obj.id)
}

send_message :: proc(channel_id: string, text: string, embeds: []Discord_Embed = nil) -> (Discord_Message, Request_Error) {
    msg := Send_Message_Body{text, embeds}
    body, allocation, err := make_discord_request(fmt.aprintf("channels/%s/messages", channel_id), .Post, msg)
    if err != nil {
        fmt.eprintln("Endpoint error:", err)
        return {}, err
    }
    defer client.body_destroy(body, allocation)

    message: Discord_Message
    unmarshal_err := json.unmarshal_string(body.(client.Body_Plain), &message)
    if unmarshal_err != nil {
        fmt.eprintln("Failed to unmarshal response body:", unmarshal_err)
        return {}, err
    }

    return message, nil
}

edit_message :: proc(channel_id: string, message_id: string, text: string, embeds: []Discord_Embed = nil) -> (Discord_Message, Request_Error) {
    msg := Send_Message_Body{text, embeds}
    body, allocation, err := make_discord_request(fmt.aprintf("channels/%s/messages/%s", channel_id, message_id), .Patch, msg)
    if err != nil {
        fmt.eprintln("Endpoint error:", err)
        return {}, err
    }
    defer client.body_destroy(body, allocation)

    message: Discord_Message
    unmarshal_err := json.unmarshal_string(body.(client.Body_Plain), &message)
    if unmarshal_err != nil {
        fmt.eprintln("Failed to unmarshal response body:", unmarshal_err)
        return {}, err
    }

    return message, nil
}

delete_message :: proc(channel_id: string, message_id: string) {
    body, allocation, err := make_discord_request(fmt.aprintf("channels/%s/messages/%s", channel_id, message_id), .Delete)
    if err != nil {
        fmt.eprintln("Endpoint error:", err)
        return
    }
    defer client.body_destroy(body, allocation)
}

make_discord_request :: proc(endpoint: string, method: http.Method = .Get, body: any = nil) -> (client.Body_Type, bool, Request_Error) {
    url := fmt.aprintf("https://discord.com/api/v10/%s", endpoint)

    req: client.Request
    client.request_init(&req, method)
    defer client.request_destroy(&req)

    // Necessary headers as per https://discord.com/developers/docs/reference#http-api
    req.headers._kv["user-agent"] = "DiscordBot (https://github.com/fatshark-kra/odin-discordbot, 0.0.1)"
    req.headers._kv["content-type"] = "application/json"
    req.headers._kv["authorization"] = fmt.aprintf("Bot %s", os.get_env("DISCORD_TOKEN"))

    if body != nil {
        if body_err := client.with_json(&req, body); body_err != nil {
            fmt.eprintln("JSON error:", body_err)
            return nil, false, body_err
        }
    }

    res, req_err := client.request(&req, url)
    if req_err != nil {
        fmt.eprintln("Request failed:", req_err)
        return nil, false, req_err
    }
    defer client.response_destroy(&res)

    body, allocation, body_err := client.response_body(&res)
    if body_err != nil {
        fmt.eprintln("Error retrieving response body:", body_err)
        return nil, false, body_err
    }

    return body, allocation, nil
}