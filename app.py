from flask import Flask, render_template, request, Response, jsonify
import subprocess
import os
import signal

app = Flask(__name__)
current_process = None

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/start', methods=['POST'])
def start_process():
    global current_process
    folder = request.form.get('folder', '/media')
    
    def generate():
        global current_process
        current_process = subprocess.Popen(
            ['/app/remove_subs.sh', folder],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1,
            preexec_fn=os.setsid
        )
        for line in iter(current_process.stdout.readline, ''):
            yield line
            
        current_process.stdout.close()
        current_process.wait()
        current_process = None

    return Response(generate(), mimetype='text/plain')

@app.route('/stop', methods=['POST'])
def stop_process():
    global current_process
    if current_process:
        try:
            os.killpg(os.getpgid(current_process.pid), signal.SIGTERM)
            current_process = None
            return jsonify({"status": "succes"})
        except Exception as e:
            return jsonify({"status": "fout", "message": str(e)})
    return jsonify({"status": "geen proces"})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
