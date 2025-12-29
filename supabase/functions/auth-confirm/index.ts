import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

serve(async (req: Request) => {
    const html = `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>Gossip - Email Confirmed</title>
      <style>
        body {
          background-color: #000000;
          color: #ffffff;
          font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
          display: flex;
          flex-direction: column;
          align-items: center;
          justify-content: center;
          height: 100vh;
          margin: 0;
          text-align: center;
        }
        h1 {
          font-size: 24px;
          margin-bottom: 16px;
          background: linear-gradient(45deg, #8E2DE2, #4A00E0);
          -webkit-background-clip: text;
          -webkit-text-fill-color: transparent;
        }
        p {
          color: #888;
          margin-bottom: 32px;
        }
        .button {
          background: linear-gradient(45deg, #8E2DE2, #4A00E0);
          color: white;
          padding: 12px 24px;
          border-radius: 24px;
          text-decoration: none;
          font-weight: bold;
          box-shadow: 0 4px 15px rgba(74, 0, 224, 0.4);
          transition: transform 0.2s;
        }
        .button:active {
          transform: scale(0.95);
        }
      </style>
    </head>
    <body>
      <h1>Email Confirmed!</h1>
      <p>Your account has been successfully verified.</p>
      <a id="appLink" href="#" class="button">Open App</a>

      <script>
        // Get the hash from the URL (contains access_token, etc.)
        const hash = window.location.hash;
        
        // Construct the deep link
        // We use 'login-callback' as the host to match typical deep link patterns, 
        // but verify what your app expects. 
        // If your app just needs to open, 'gossip://home' might work, 
        // but typically Supabase auth expects the fragments.
        const deepLink = 'gossip://login-callback' + hash;

        document.getElementById('appLink').href = deepLink;

        // Try to automatically redirect
        setTimeout(() => {
          window.location.href = deepLink;
        }, 1000);
      </script>
    </body>
    </html>
  `

    return new Response(html, {
        headers: { "content-type": "text/html" },
    })
})
