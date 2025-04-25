from flask import Flask, request
from twilio.twiml.messaging_response import MessagingResponse
from google.oauth2.service_account import Credentials
from googleapiclient.discovery import build
import json
import re
import datetime
import threading
import time
import requests

app = Flask(__name__)

# --- Configuración Google Sheets ---
SCOPES = ['https://www.googleapis.com/auth/spreadsheets']
SPREADSHEET_ID = '15bKRhmzNLFvFfLLFu-E6AAAQh5qkaXDC'  # Tu ID de hoja de cálculo
credenciales = Credentials.from_service_account_file('credenciales.json', scopes=SCOPES)
servicio = build('sheets', 'v4', credentials=credenciales)

# --- Estado de cada usuario ---
estado_usuario = {}

# --- Cargar ejercicios por día ---
with open('ejercicios.json', 'r', encoding='utf-8') as f:
    ejercicios_por_dia = json.load(f)

# --- Función para responder mensajes de WhatsApp (Twilio) ---
def enviar_mensaje(respuesta, texto):
    respuesta.message(texto)

# --- Función para enviar mensajes automáticos con WPPConnect ---
def enviar_mensaje_wpp(numero, texto):
    try:
        url = "http://localhost:21465/api/send-message"
        headers = {
            "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzZXNzaW9uIjoibWktc2VzaW9uIiwiaWF0IjoxNzQ1NTI4ODEyLCJleHAiOjE3NDU2MTUyMTJ9.TRyPNuphXxRmiz_8xOl3hcXunWmM2oJpkJ46Z6_jV0M",
            "Content-Type": "application/json"
        }
        payload = {
            "session": "mi-sesion",
            "phone": numero.replace("whatsapp:", ""),  # limpiar formato
            "text": texto
        }
        r = requests.post(url, headers=headers, json=payload)
        print(f"[✔] Enviado a {numero}: {texto}")
    except Exception as e:
        print(f"❌ Error al enviar mensaje a {numero}: {e}")

# --- Ruta para manejar mensajes entrantes ---
@app.route("/whatsapp", methods=["POST"])
def whatsapp():
    mensaje = request.form.get('Body')
    from_num = request.form.get('From')
    respuesta = MessagingResponse()

    if from_num not in estado_usuario:
        estado_usuario[from_num] = {
            "dia_actual": 1,
            "ejercicio_idx": 0,
            "semana": 1
        }

    estado = estado_usuario[from_num]
    dia = f"dia{estado['dia_actual']}"
    ejercicios = ejercicios_por_dia.get(dia, [])

    if not ejercicios:
        enviar_mensaje(respuesta, "❌ No hay ejercicios para hoy.")
        return str(respuesta)

    if estado["ejercicio_idx"] < len(ejercicios):
        ejercicio_actual = ejercicios[estado["ejercicio_idx"]]
        peso_match = re.search(r"(\d+)(kg)?", mensaje)

        if peso_match:
            peso = peso_match.group(1)
            fila = ejercicio_actual["fila"]
            col = ejercicio_actual["columna"]
            hoja = f"Semana {estado['semana']}"
            celda = f"{col}{fila}"

            servicio.spreadsheets().values().update(
                spreadsheetId=SPREADSHEET_ID,
                range=f'{hoja}!{celda}',
                valueInputOption="RAW",
                body={"values": [[peso]]}
            ).execute()

            estado["ejercicio_idx"] += 1

            if estado["ejercicio_idx"] < len(ejercicios):
                siguiente = ejercicios[estado["ejercicio_idx"]]
                enviar_mensaje(respuesta, f"➡️ {siguiente['nombre']} ({siguiente['reps']}) – ¿Qué peso hiciste?")
            else:
                enviar_mensaje(respuesta, "✅ ¡Entrenamiento del día completado!")
                estado["dia_actual"] += 1
                estado["ejercicio_idx"] = 0
                if estado["dia_actual"] > 5:
                    estado["dia_actual"] = 1
                    estado["semana"] += 1
        else:
            enviar_mensaje(respuesta, "❗ Por favor responde solo con el peso en kg. Ej: 40")
    return str(respuesta)

# --- Recordatorio automático diario ---
def recordatorio_diario():
    ya_enviado_730 = False
    ya_enviado_1200 = False

    while True:
        ahora = datetime.datetime.now()
        hora_actual = ahora.strftime("%H:%M")

        if hora_actual == "07:30" and not ya_enviado_730:
            for usuario in estado_usuario:
                enviar_mensaje_wpp(usuario, "🏋️‍♂️ ¡Buenos días! ¿Hoy vas al gym?")
            ya_enviado_730 = True

        if hora_actual == "12:00" and not ya_enviado_1200:
            for usuario in estado_usuario:
                enviar_mensaje_wpp(usuario, "👀 ¿Seguro que no vas al gimnasio hoy?")
            ya_enviado_1200 = True

        # Reset diario a medianoche
        if hora_actual == "00:00":
            ya_enviado_730 = False
            ya_enviado_1200 = False

        time.sleep(30)

# --- Lanzar el hilo del recordatorio ---
thr = threading.Thread(target=recordatorio_diario)
thr.daemon = True
thr.start()

# --- Iniciar servidor Flask ---
if __name__ == "__main__":
   import os
port = int(os.environ.get("PORT", 5000))
app.run(host="0.0.0.0", port=port)


