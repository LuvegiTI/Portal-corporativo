import os
import tkinter as tk
from tkinter import filedialog, messagebox
from PIL import Image, ImageTk
import fitz  # PyMuPDF (Indispensable para análisis de capas)

# --- PALETA LUVEGI ---
BG_DARK   = "#1e2330"
BG_MID    = "#252b3b"
BG_LIGHT  = "#2d3450"
ACCENT    = "#4a90d9" 
ACCENT2   = "#5cb85c" 
TEXT_W    = "#ffffff"
TEXT_G    = "#aab4cc"

class ValidadorInteligente:
    def __init__(self, root):
        self.root = root
        self.root.title("✍️ Validador de Espacios Luvegi TI")
        self.root.configure(bg=BG_DARK)
        self.root.geometry("1100x800")

        self.firma_path = None
        self.pdf_list = []
        self.preview_doc = None
        self.var_tamano = tk.DoubleVar(value=25.0)

        self._build_ui()

    def _analizar_pagina_especifica(self, pagina):
        """
        Analiza CUALQUIER página y detecta el espacio en blanco real 
        ignorando el pie de página decorativo.
        """
        # Definimos el límite del pie de página (80 puntos desde el fondo)
        margen_inferior_limite = pagina.rect.height - 80
        
        # Extraemos todos los elementos que ocupan espacio (texto, imágenes, líneas)
        bloques = pagina.get_text("dict")["blocks"]
        y_max_ocupado = 0
        
        for b in bloques:
            # Si el elemento está arriba del pie de página, registramos su posición
            if b["bbox"][3] < margen_inferior_limite:
                y_max_ocupado = max(y_max_ocupado, b["bbox"][3])
        
        # También detectamos líneas o cuadros (como los de las tablas de Odoo)
        for dibujo in pagina.get_drawings():
            if dibujo["rect"][3] < margen_inferior_limite:
                y_max_ocupado = max(y_max_ocupado, dibujo["rect"][3])

        # Si la página está muy vacía, ponemos un mínimo
        if y_max_ocupado == 0: y_max_ocupado = pagina.rect.height * 0.5
        
        # Calculamos el centro del espacio blanco entre el contenido y el pie de página
        espacio_blanco = margen_inferior_limite - y_max_ocupado
        
        # Si hay suficiente espacio (más de 60px), centramos ahí. 
        # Si no, lo ponemos justo encima del pie de página.
        if espacio_blanco > 60:
            posicion_y = y_max_ocupado + (espacio_blanco / 2)
        else:
            posicion_y = margen_inferior_limite - 30
            
        return (pagina.rect.width / 2), posicion_y

    def _build_ui(self):
        # Panel lateral
        side = tk.Frame(self.root, bg=BG_MID, width=280)
        side.pack(side="left", fill="y", padx=10, pady=10)
        side.pack_propagate(False)

        tk.Label(side, text="FIRMA", bg=ACCENT, fg=TEXT_W, font=("Arial", 10, "bold")).pack(fill="x", pady=(0,10))
        tk.Button(side, text="📂 Cargar Firma", command=self._cargar_firma, bg=BG_LIGHT, fg=TEXT_W).pack(fill="x", padx=10, pady=5)
        self.canvas_mini = tk.Canvas(side, bg=BG_DARK, height=80, highlightthickness=0)
        self.canvas_mini.pack(fill="x", padx=10, pady=5)

        tk.Label(side, text="LISTA DE PDFS", bg=BG_MID, fg=TEXT_G).pack(pady=10)
        tk.Button(side, text="➕ Agregar Documentos", command=self._agregar_pdfs, bg=BG_LIGHT, fg=TEXT_W).pack(fill="x", padx=10, pady=5)
        self.lista_box = tk.Listbox(side, bg=BG_DARK, fg=TEXT_W, bd=0, highlightthickness=0)
        self.lista_box.pack(fill="x", padx=10, pady=5, expand=True)
        self.lista_box.bind("<<ListboxSelect>>", self._on_select_pdf)

        tk.Label(side, text="TAMAÑO", bg=BG_MID, fg=TEXT_G).pack()
        tk.Scale(side, from_=10, to=50, orient="horizontal", variable=self.var_tamano, bg=BG_MID, fg=TEXT_W).pack(fill="x", padx=10)
        
        tk.Button(side, text="🚀 FIRMAR TODO EL LOTE", command=self._procesar_lote_completo, bg=ACCENT2, fg=TEXT_W, font=("Arial", 10, "bold"), pady=15).pack(fill="x", padx=10, pady=20)

        # Visualizador
        self.canvas = tk.Canvas(self.root, bg="#111318", highlightthickness=0)
        self.canvas.pack(side="right", fill="both", expand=True, padx=10, pady=10)

    def _cargar_firma(self):
        path = filedialog.askopenfilename(filetypes=[("Imágenes", "*.png *.jpg")])
        if path:
            self.firma_path = path
            img = Image.open(path)
            img.thumbnail((180, 60))
            self._tk_mini = ImageTk.PhotoImage(img)
            self.canvas_mini.delete("all")
            self.canvas_mini.create_image(90, 40, image=self._tk_mini)

    def _agregar_pdfs(self):
        paths = filedialog.askopenfilenames(filetypes=[("PDF", "*.pdf")])
        for p in paths:
            if p not in self.pdf_list:
                self.pdf_list.append(p)
                self.lista_box.insert("end", f"📄 {os.path.basename(p)}")
        if self.pdf_list: self._cargar_pdf(self.pdf_list[0])

    def _cargar_pdf(self, path):
        self.preview_doc = fitz.open(path)
        self._mostrar_preview()

    def _mostrar_preview(self):
        if not self.preview_doc: return
        cw, ch = self.canvas.winfo_width(), self.canvas.winfo_height()
        if cw < 50: return
        
        pagina = self.preview_doc[0]
        # Detectamos para la visualización del primer archivo
        px, py = self._analizar_pagina_especifica(pagina)
        
        scale = min(cw/pagina.rect.width, ch/pagina.rect.height) * 0.9
        pix = pagina.get_pixmap(matrix=fitz.Matrix(scale, scale))
        img = Image.frombytes("RGB", [pix.width, pix.height], pix.samples)
        
        off_x, off_y = (cw - img.width) // 2, (ch - img.height) // 2
        self._tk_preview = ImageTk.PhotoImage(img)
        self.canvas.delete("all")
        self.canvas.create_image(off_x, off_y, anchor="nw", image=self._tk_preview)
        
        # Dibujar marcador de donde iría la firma detectada
        fw_scaled = (pagina.rect.width * (self.var_tamano.get()/100)) * scale
        self.canvas.create_rectangle(off_x + (px*scale) - (fw_scaled/2), 
                                     off_y + (py*scale) - 20, 
                                     off_x + (px*scale) + (fw_scaled/2), 
                                     off_y + (py*scale) + 20, 
                                     outline="#00f2ff", width=2)

    def _on_select_pdf(self, e):
        sel = self.lista_box.curselection()
        if sel: self._cargar_pdf(self.pdf_list[sel[0]])

    def _procesar_lote_completo(self):
        """ 
        ESTA ES LA FUNCIÓN CLAVE: 
        Entra en cada PDF, analiza SU contenido y busca SU espacio.
        """
        if not self.firma_path or not self.pdf_list:
            messagebox.showwarning("Luvegi TI", "Carga una firma y al menos un PDF.")
            return
        
        contador = 0
        for path in self.pdf_list:
            try:
                # Abrimos el documento actual del bucle
                doc = fitz.open(path)
                
                for pagina in doc:
                    # ANALIZAMOS ESTA PÁGINA EN PARTICULAR
                    x_centro, y_encontrada = self._analizar_pagina_especifica(pagina)
                    
                    # Preparamos la imagen de la firma
                    img_firma = Image.open(self.firma_path)
                    ancho_f = pagina.rect.width * (self.var_tamano.get() / 100)
                    alto_f = ancho_f * (img_firma.height / img_firma.width)
                    
                    # Definimos el área exacta basada en el análisis de esta página
                    area_firma = fitz.Rect(
                        x_centro - (ancho_f / 2), 
                        y_encontrada - (alto_f / 2), 
                        x_centro + (ancho_f / 2), 
                        y_encontrada + (alto_f / 2)
                    )
                    
                    # Insertamos la firma en el espacio blanco detectado
                    pagina.insert_image(area_firma, filename=self.firma_path)
                
                # Guardamos cada archivo con su propia detección
                doc.save(path.replace(".pdf", "_firmado.pdf"))
                doc.close()
                contador += 1
            except Exception as e:
                print(f"Error procesando {path}: {e}")

        messagebox.showinfo("Luvegi TI", f"¡Listo! Se analizaron y firmaron {contador} PDFs individualmente.")

if __name__ == "__main__":
    root = tk.Tk()
    app = ValidadorInteligente(root)
    root.mainloop()