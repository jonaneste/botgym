from flask import Flask, request
from twilio.twiml.messaging_response import MessagingResponse
from google.oauth2.service_account import Credentials
from googleapiclient.discovery import build
import json
import re
import datetime
import threading
import time

app = Flask(__name__)

# --- Configuración de Google Sheets ---
SCOPES = ['https://www.googleapis.com/auth/spreadsheets']
SPREADSHEET_ID = '15bKRhmzNLFvFfLLFu-E6AAAQh5qkaXDC'  # ← ID de tu Google Sheets
credenciales = Credentials.from_service_account_file('credenciales.json', scopes=SCOPES)
servicio = build('sheets', 'v4', credentials=credenciales)

# --- Estados por usuario ---
estado_usuario = {}

# --- Cargar ejercicios por día desde JSON ---
with open('ejercicios.json', 'r', encoding='utf-8') as f:
    ejercicios_por_dia = json.load(f)

# --- Función para enviar mensajes fácilmente ---
def enviar_mensaje(respuesta, texto):
    respuesta.message(texto)

# --- Ruta principal del bot (conectada desde WPPConnect con Ngrok) ---
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
        enviar_mensaje(respuesta, "❌ No hay ejercicios programados para hoy.")
        return str(respuesta)

    # Revisar si estamos esperando un peso
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
                enviar_mensaje(
                    respuesta,
                    f"➡️ {siguiente['nombre']} ({siguiente['reps']}) – ¿Qué peso hiciste?"
                )
            else:
                enviar_mensaje(respuesta, "✅ ¡Entrenamiento del día completado!")
                estado["dia_actual"] += 1
                estado["ejercicio_idx"] = 0

                if estado["dia_actual"] > 5:
                    estado["dia_actual"] = 1
                    estado["semana"] += 1
        else:
            enviar_mensaje(respuesta, "❗ Por favor responde solo con el peso en kg. Ej: 40")
    else:
        enviar_mensaje(respuesta, "❗ No entendí tu mensaje. Solo responde con el peso. Ej: 40")

    return str(respuesta)

# --- Recordatorio automático a las 7:30 ---
def recordatorio_diario():
    while True:
        ahora = datetime.datetime.now()
        if ahora.hour == 7 and ahora.minute == 30:
            for usuario in estado_usuario:
                print(f"[Recordatorio enviado a {usuario}]: ¿Hoy vas al gym?")
                # Aquí podrías usar Twilio o WppConnect para enviar el mensaje automático
        time.sleep(60)

# --- Lanzar hilo del recordatorio diario ---
thr = threading.Thread(target=recordatorio_diario)
thr.daemon = True
thr.start()

# --- Iniciar el servidor Flask ---
if __name__ == "__main__":
    app.run(port=5000)
