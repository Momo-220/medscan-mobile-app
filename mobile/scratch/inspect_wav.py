import wave
import struct

def inspect_wav(file_path):
    try:
        with wave.open(file_path, 'rb') as w:
            params = w.getparams()
            print(f"File: {file_path}")
            print(f"Channels: {params.nchannels}")
            print(f"Sample Width: {params.sampwidth}")
            print(f"Framerate: {params.framerate}")
            print(f"Frames: {params.nframes}")
            
            # Read frames
            frames = w.readframes(params.nframes)
            
            # Determine format
            if params.sampwidth == 2:
                fmt = f"<{params.nframes * params.nchannels}h"
                data = struct.unpack(fmt, frames)
            elif params.sampwidth == 1:
                fmt = f"<{params.nframes * params.nchannels}B"
                data = struct.unpack(fmt, frames)
                data = [x - 128 for x in data]
            else:
                print("Unsupported sample width for simple inspect")
                return
            
            if len(data) == 0:
                print("Error: Audio data is empty!")
                return
                
            abs_data = [abs(x) for x in data]
            max_val = max(abs_data)
            mean_val = sum(abs_data) / len(abs_data)
            print(f"Max Amplitude: {max_val}")
            print(f"Mean Amplitude: {mean_val}")
            
            if max_val == 0:
                print("Warning: THIS FILE IS COMPLETELY SILENT (ALL ZEROES)!")
            elif max_val < 100:
                print("Warning: This file is extremely quiet!")
            else:
                print("File has active sound data.")
    except Exception as e:
        print(f"Error reading file: {e}")

inspect_wav("ios/Runner/alarme_douce.wav")
inspect_wav("ios/alarme_douce.wav")
inspect_wav("android/app/src/main/res/raw/alarme_douce.wav")
