import os, sys, logging
os.chdir(r"D:\Downloads\offline model")
logging.disable(logging.CRITICAL)
os.environ["ONNX_DISABLE_WARNINGS"] = "1"
import warnings
warnings.filterwarnings("ignore")

import uvicorn
from api import app

if __name__ == "__main__":
    print("Starting Photo Organizer on http://localhost:8001", flush=True)
    uvicorn.run(app, host="0.0.0.0", port=8001, log_level="error")
