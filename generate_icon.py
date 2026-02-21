import zlib
import struct
import math

def generate_png(width, height, output_path):
    # Colors
    bg_color = (18, 18, 18)  # #121212
    accent_color = (68, 138, 255) # #448AFF Blue Accent
    white = (255, 255, 255)

    data = bytearray()
    
    # Simple anti-aliasing logic (just sampling the center of the pixel)
    for y in range(height):
        row = bytearray()
        row.append(0) # Filter type
        for x in range(width):
            # Coordinates normalized to -1..1
            nx = (x / width) * 2 - 1
            ny = (y / height) * 2 - 1
            
            dist = math.sqrt(nx*nx + ny*ny)
            
            # Default Background
            r, g, b = bg_color
            a = 255

            # Draw Circle Background (Blue Accent)
            if dist < 0.85:
                r, g, b = accent_color
            
            # Draw "K" shape (White)
            # Vertical bar
            in_bar = -0.4 < nx < -0.15 and -0.5 < ny < 0.5
            
            # Upper diagonal
            in_upper = False
            if nx > -0.15 and ny < 0:
                # y = -x - 0.1 (roughly)
                # distance from line x + y + 0.1 = 0
                dist_line = abs(nx + ny + 0.1) / math.sqrt(2)
                if dist_line < 0.12 and nx < 0.4 and ny > -0.5:
                    in_upper = True

            # Lower diagonal
            in_lower = False
            if nx > -0.15 and ny > 0:
                 # y = x - 0.1
                 dist_line = abs(nx - ny - 0.1) / math.sqrt(2)
                 if dist_line < 0.12 and nx < 0.4 and ny < 0.5:
                     in_lower = True

            if (in_bar or in_upper or in_lower) and dist < 0.85:
                r, g, b = white

            # Write pixel
            row.extend([r, g, b, a])
        data.extend(row)

    # PNG Header
    png_sig = b'\x89PNG\r\n\x1a\n'
    
    # IHDR Chunk
    ihdr_content = struct.pack("!IIBBBBB", width, height, 8, 6, 0, 0, 0)
    ihdr = struct.pack("!I", len(ihdr_content)) + b'IHDR' + ihdr_content + struct.pack("!I", zlib.crc32(b'IHDR' + ihdr_content) & 0xffffffff)

    # IDAT Chunk
    compressed = zlib.compress(data)
    idat = struct.pack("!I", len(compressed)) + b'IDAT' + compressed + struct.pack("!I", zlib.crc32(b'IDAT' + compressed) & 0xffffffff)

    # IEND Chunk
    iend_content = b''
    iend = struct.pack("!I", len(iend_content)) + b'IEND' + iend_content + struct.pack("!I", zlib.crc32(b'IEND' + iend_content) & 0xffffffff)

    with open(output_path, 'wb') as f:
        f.write(png_sig)
        f.write(ihdr)
        f.write(idat)
        f.write(iend)

if __name__ == "__main__":
    generate_png(512, 512, "assets/icon.png")
    print("Icon generated successfully at assets/icon.png")
