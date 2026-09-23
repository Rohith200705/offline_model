import sys, os
os.chdir(r"D:\Downloads\offline model")
try:
    from api import app
    print("IMPORTS OK")
    import uvicorn
    print("STARTING on port 8001...")
    uvicorn.run(app, host="0.0.0.0", port=8001, log_level="error")
except Exception as e:
    import traceback
    traceback.print_exc()
