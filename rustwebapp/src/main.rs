// --- 1. IMPORTACIONES (SIMPLIFICADAS, SIN RUSTLS) ---
use actix_web::{get, web, App, HttpRequest, HttpResponse, HttpServer, Responder};
use chrono::Local;
use std::sync::Mutex;
// Se eliminan las importaciones de rustls, File y BufReader

// --- 2. STRUCT DE APPSTATE (CONTADOR) ---
struct AppState {
    counter: Mutex<usize>,
}

// --- 3. FUNCIÓN GET_RUST_VERSION (CORREGIDA) ---
fn get_rust_version() -> &'static str {
    env!("COMPILER_VERSION")
}

// --- 4. FUNCIÓN SSL (ELIMINADA) ---
// La función load_rustls_config() se ha eliminado por completo.


// --- 5. RUTA INDEX HTML (¡CON VÍDEO DE FONDO!) ---
#[get("/")]
async fn index(req: HttpRequest, data: web::Data<AppState>) -> impl Responder {
    let mut counter = data.counter.lock().unwrap();
    *counter += 1;
    let current_count = *counter;

    let client_ip = req.connection_info().realip_remote_addr().unwrap_or("IP no encontrada").to_string();
    let user_agent = req.headers().get("User-Agent").and_then(|h| h.to_str().ok()).unwrap_or("Navegador no encontrado");
    let server_time = Local::now().format("%Y-%m-%d %H:%M:%S").to_string();
    let rust_version = get_rust_version();

    let html_response = format!(r###"
        <!DOCTYPE html>
        <html lang="es">
        <head><meta charset="UTF-8"><title> Información del Despliegue</title>
        <style>
            body {{
                margin: 0; padding: 0; font-family: sans-serif;
                background-color: #2e2e2e; color: #f1f1f1;
                overflow: hidden;
            }}
            #video-background {{
                position: fixed; right: 0; bottom: 0;
                min-width: 100%; min-height: 100%;
                z-index: -100; background-size: cover; filter: brightness(0.7);
            }}
            #video-overlay {{
                position: fixed; top: 0; left: 0;
                width: 100%; height: 100%;
                background: rgba(0, 0, 0, 0.4); z-index: -99;
            }}
            .container {{
                position: relative; z-index: 1;
                background-color: rgba(60, 60, 60, 0.8);
                backdrop-filter: blur(5px);
                padding: 2.5em; border-radius: 12px;
                max-width: 900px; box-shadow: 0 8px 16px rgba(0,0,0,0.5);
                margin: 5vh auto;
            }}
            h1 {{ color: #00a8e8; margin-bottom: 0.8em; text-align: center; font-size: 2.5em; }}
            li {{ margin-bottom: 12px; word-wrap: break-word; font-size: 1.1em; }}
            img.badge {{ margin-top: 20px; display: block; margin-left: auto; margin-right: auto; }}
            .contact-link {{
                margin-top: 30px; font-size: 1.2em; text-align: center;
            }}
            .contact-link a {{
                display: inline-block; background-color: #00a8e8;
                color: #ffffff; padding: 15px 30px; border-radius: 8px;
                text-decoration: none; font-weight: bold;
                transition: background-color 0.3s ease;
            }}
            .contact-link a:hover {{
                background-color: #007bb6; transform: scale(1.02);
            }}
        </style>
        </head><body>
            <div id="video-overlay"></div>
            <video autoplay muted loop id="video-background">
                <source src="https://assets.mixkit.co/videos/preview/mixkit-space-darkness-4428-large.mp4" type="video/mp4">
                Tu navegador no soporta vídeos HTML5.
            </video>

            <div class="container">
                <h1> ¡Aplicación Desplegada con Rust! </h1> <img src="/badge.svg" alt="Contador de visitas" class="badge"/>
                
                <p class="contact-link">
                    <a href="/contact">Ir al Formulario de Contacto &rarr;</a>
                </p>

                <ul>
                    <li><strong>Visitas Totales:</strong> {}</li>
                    <li><strong>Fecha y Hora del Servidor:</strong> {}</li>
                    <li><strong>Tu Dirección IP:</strong> {}</li>
                    <li><strong>Tu Navegador (User-Agent):</strong> {}</li>
                    <li><strong>Versión de Rust (compilador):</strong> {}</li>
                </ul>
            </div></body></html>
        "###,
        current_count, server_time, client_ip, user_agent, rust_version
    );

    HttpResponse::Ok().content_type("text/html; charset=utf-8").body(html_response)
}

// --- 6. RUTA BADGE SVG (SIN CAMBIOS) ---
#[get("/badge.svg")]
async fn badge(data: web::Data<AppState>) -> impl Responder {
    let count = data.counter.lock().unwrap();
    let count_str = count.to_string();
    let text_width = count_str.len() * 8 + 10;
    let total_width = 60 + text_width;

    let svg = format!(r###"<svg xmlns="http://www.w3.org/2000/svg" width="{total_width}" height="20" role="img">
            <title>Visitas: {count}</title>
            <linearGradient id="s" x2="0" y2="100%"><stop offset="0" stop-color="#bbb" stop-opacity=".1"/><stop offset="1" stop-opacity=".1"/></linearGradient>
            <clipPath id="r"><rect width="{total_width}" height="20" rx="3" fill="#fff"/></clipPath>
            <g clip-path="url(#r)">
                <rect width="60" height="20" fill="#555"/><rect x="60" width="{text_width}" height="20" fill="#00a8e8"/><rect width="{total_width}" height="20" fill="url(#s)"/>
            </g>
            <g fill="#fff" text-anchor="middle" font-family="Verdana,Geneva,sans-serif" font-size="110">
                <text x="300" y="150" fill="#010101" fill-opacity=".3" transform="scale(.1)" textLength="500">Visitas</text>
                <text x="300" y="140" transform="scale(.1)" textLength="500">Visitas</text>
                <text x="{text_anchor}" y="150" fill="#010101" fill-opacity=".3" transform="scale(.1)" textLength="{text_length}">{count}</text>
                <text x="{text_anchor}" y="140" transform="scale(.1)" textLength="{text_length}">{count}</text>
            </g>
        </svg>"###,
        total_width = total_width, text_width = text_width, count = count_str,
        text_anchor = (60 + text_width / 2) * 10, text_length = (text_width - 10) * 10
    );

    HttpResponse::Ok().content_type("image/svg+xml; charset=utf-8")
        .append_header(("Cache-Control", "no-cache, no-store, must-revalidate"))
        .append_header(("Pragma", "no-cache"))
        .append_header(("Expires", "0"))
        .body(svg)
}

// --- 7. RUTA PÁGINA DE CONTACTO (ESTILO DE VÍDEO) ---
#[get("/contact")]
async fn contact_page() -> impl Responder {
    let html_response = r###"
    <!DOCTYPE html>
    <html lang="es">
    <head>
        <meta charset="UTF-8">
        <title>Contacto</title>
        <style>
            body {{
                margin: 0; padding: 0; font-family: sans-serif;
                background-color: #2e2e2e; color: #f1f1f1;
                overflow: hidden;
            }}
            #video-background {{
                position: fixed; right: 0; bottom: 0;
                min-width: 100%; min-height: 100%;
                z-index: -100; background-size: cover; filter: brightness(0.7);
            }}
            #video-overlay {{
                position: fixed; top: 0; left: 0;
                width: 100%; height: 100%;
                background: rgba(0, 0, 0, 0.4); z-index: -99;
            }}
            .container {{
                position: relative; z-index: 1;
                background-color: rgba(60, 60, 60, 0.8);
                backdrop-filter: blur(5px);
                padding: 2.5em; border-radius: 12px;
                max-width: 900px; box-shadow: 0 8px 16px rgba(0,0,0,0.5);
                margin: 5vh auto;
            }}
            h1 {{ color: #00a8e8; }}
            a {{ color: #00a8e8; text-decoration: none; }}
            a:hover {{ text-decoration: underline; }}
            /* Estilos para el formulario */
            form {{ display: flex; flex-direction: column; }}
            label {{ margin-top: 15px; margin-bottom: 5px; font-weight: bold; }}
            input, textarea {{ padding: 10px; border-radius: 5px; border: none; background-color: #555; color: #f1f1f1; font-size: 1em; }}
            textarea {{ min-height: 150px; resize: vertical; }}
            button {{ background-color: #00a8e8; color: white; padding: 12px; border: none; border-radius: 5px; cursor: pointer; margin-top: 20px; font-size: 1.1em; font-weight: bold; }}
            button:hover {{ background-color: #007aae; }}
        </style>
    </head>
    <body>
        <div id="video-overlay"></div>
        <video autoplay muted loop id="video-background">
            <source src="https://assets.mixkit.co/videos/preview/mixkit-space-darkness-4428-large.mp4" type="video/mp4">
            Tu navegador no soporta vídeos HTML5.
        </video>

        <div class="container">
            <h1>Formulario de Contacto</h1>
            <p>Este formulario todavía no envía datos. Es solo la parte visual.</p>
            
            <form method="post">
                <label for="name">Nombre:</label>
                <input type="text" id="name" name="name" required>
                <label for="email">Email:</label>
                <input type="email" id="email" name="email" required>
                <label for="message">Mensaje:</label>
                <textarea id="message" name="message" required></textarea>
                <button type="submit">Enviar</button>
            </form>
            <p style="margin-top: 20px;"><a href="/">&larr; Volver a la página principal</a></p>
        </div>
    </body>
    </html>
    "###;

    HttpResponse::Ok()
        .content_type("text/html; charset=utf-8")
        .body(html_response)
}


// --- 8. FUNCIÓN MAIN (SOLO HTTP) ---
#[actix_web::main]
async fn main() -> std::io::Result<()> {
    
    let app_state = web::Data::new(AppState {
        counter: Mutex::new(0),
    });

    // Se elimina la carga de config SSL
    // let config = load_rustls_config();

    println!(" Servidor iniciado en:");
    println!("   HTTP:  http://0.0.0.0:8081");
    // Se elimina el log de HTTPS

    HttpServer::new(move || {
        App::new()
            .app_data(app_state.clone())
            .service(index)
            .service(badge)
            .service(contact_page)
    })
    
    .bind(("0.0.0.0", 8081))?
    // Se elimina .bind_rustls_0_23(...)
    
    .run()
    .await
}
