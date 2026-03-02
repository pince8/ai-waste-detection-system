from ultralytics import YOLO
from fastapi import FastAPI, File, UploadFile
import shutil
import uuid
import os

app = FastAPI()

model = YOLO("temp/best.pt")

UPLOAD_DIR = "temp/uploads"
os.makedirs(UPLOAD_DIR, exist_ok=True)

@app.post("/predict")
async def predict(file: UploadFile = File(...)):
    file_id = str(uuid.uuid4())
    image_path = f"{UPLOAD_DIR}/{file_id}.jpg"

    with open(image_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    results = model(image_path)

    detections = []

    for r in results:
        for box in r.boxes:
            detections.append({
                "class_id": int(box.cls[0]),
                "confidence": float(box.conf[0]),
                "bbox": box.xyxy[0].tolist()
            })

    return {"detections": detections}
@app.get("/")
def root():
    return {"status": "ok"}

