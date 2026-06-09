#!/usr/bin/env python3
"""
==============================================================
  VALIDADOR INTELIGENTE DE FIRMA  –  LUVEGI INGENIEROS
  Detecta automáticamente el espacio en blanco de cada PDF
  y posiciona la firma ahí sin configuración manual.

  Requisitos:
      pip install pymupdf pillow

  Uso:
      python validador_firma_luvegi.py
==============================================================
"""

import os
import io
import tkinter as tk
from tkinter import filedialog, messagebox, ttk
from PIL import Image, ImageTk
import fitz  # PyMuPDF

# ── PALETA LUVEGI ─────────────────────────────────────────────────────────────
BG_DARK  = "#1e2330"
BG_MID   = "#252b3b"
BG_LIGHT = "#2d3450"
ACCENT   = "#4a90d9"
ACCENT2  = "#5cb85c"
CYAN     = "#00c8d4"
TEXT_W   = "#ffffff"
TEXT_G   = "#aab4cc"
RED      = "#e74c3c"


# ══════════════════════════════════════════════════════════════════════════════
#  MOTOR DE DETECCIÓN DE ESPACIOS EN BLANCO
# ══════════════════════════════════════════════════════════════════════════════

def detectar_regiones_blanco(pagina: fitz.Page) -> list[dict]:
    """
    Analiza una página PDF renderizándola como imagen en escala de grises
    y detecta todas las franjas horizontales continuas en blanco.

    Retorna lista de regiones ordenadas de mayor a menor alto:
        [{"y0", "y1", "cx", "cy", "alto"}, ...]
    en coordenadas de puntos PDF.
    """
    pw = pagina.rect.width
    ph = pagina.rect.height

    # Renderizar a escala moderada (suficiente resolución, rápido)
    SCALE = 1.5
    mat = fitz.Matrix(SCALE, SCALE)
    pix = pagina.get_pixmap(matrix=mat, colorspace=fitz.csGRAY, alpha=False)
    img_w, img_h = pix.width, pix.height
    samples = pix.samples  # 1 byte por pixel

    # Umbral: pixel < 245 se considera "contenido"
    UMBRAL   = 245
    MARGEN_H = int(img_w * 0.06)   # ignorar 6% de los bordes horizontales

    # Construir mapa de filas ocupadas
    filas_con_contenido = []
    for y in range(img_h):
        fila = samples[y * img_w : (y + 1) * img_w]
        zona = fila[MARGEN_H : img_w - MARGEN_H]
        filas_con_contenido.append(any(p < UMBRAL for p in zona))

    # Suavizar: una fila solitaria de "contenido" entre blancos se ignora
    # (evita que ruido o artefactos fragmenten grandes espacios)
    for y in range(1, img_h - 1):
        if filas_con_contenido[y] and not filas_con_contenido[y-1] and not filas_con_contenido[y+1]:
            filas_con_contenido[y] = False

    # Encontrar rangos continuos de filas en blanco
    regiones = []
    en_blanco = False
    inicio = 0

    for y, ocupada in enumerate(filas_con_contenido):
        if not ocupada and not en_blanco:
            inicio = y
            en_blanco = True
        elif ocupada and en_blanco:
            regiones.append((inicio, y - 1))
            en_blanco = False
    if en_blanco:
        regiones.append((inicio, img_h - 1))

    # Convertir a puntos PDF y filtrar las muy pequeñas
    MIN_ALTO_PTS = ph * 0.04   # mínimo 4% del alto de página

    resultado = []
    for (y0_px, y1_px) in regiones:
        y0_pts = y0_px / SCALE
        y1_pts = y1_px / SCALE
        alto   = y1_pts - y0_pts
        if alto < MIN_ALTO_PTS:
            continue
        resultado.append({
            "y0"  : y0_pts,
            "y1"  : y1_pts,
            "cx"  : pw / 2,
            "cy"  : (y0_pts + y1_pts) / 2,
            "alto": alto,
        })

    # Ordenar de mayor a menor
    resultado.sort(key=lambda r: r["alto"], reverse=True)
    return resultado


def elegir_posicion_firma(regiones: list[dict],
                          pagina: fitz.Page,
                          firma_alto_pts: float) -> tuple[float, float]:
    """
    De todas las regiones en blanco elige la más apropiada para la firma.

    Criterio:
      - Debe ser al menos 80% del alto de la firma
      - Preferimos la mitad inferior de la página (firma suele ir abajo)
      - Dentro de las candidatas, la de mayor puntuación combinada
    """
    ph = pagina.rect.height

    candidatas = [r for r in regiones if r["alto"] >= firma_alto_pts * 0.80]

    if not candidatas:
        # Usar la más grande aunque sea justa
        if regiones:
            r = regiones[0]
            return r["cx"], r["cy"]
        # Fallback absoluto: 75% del alto de la página
        return pagina.rect.width / 2, ph * 0.75

    mejor = None
    mejor_score = -1.0

    for r in candidatas:
        pos_rel = r["cy"] / ph          # 0=arriba, 1=abajo
        # Bonus fuerte si está en el 40-85% del alto (zona de firma típica)
        if 0.40 <= pos_rel <= 0.85:
            bonus = 2.0
        elif pos_rel > 0.85:
            bonus = 0.8                 # muy al fondo = pie de página
        else:
            bonus = 0.5                 # muy arriba

        score = r["alto"] * bonus
        if score > mejor_score:
            mejor_score = score
            mejor = r

    return mejor["cx"], mejor["cy"]


# ══════════════════════════════════════════════════════════════════════════════
#  INSERCIÓN DE FIRMA EN PÁGINA
# ══════════════════════════════════════════════════════════════════════════════

def insertar_firma_en_pagina(pagina: fitz.Page,
                             firma_path: str,
                             tamano_pct: float,
                             opacidad: float = 1.0):
    """
    Detecta el espacio en blanco de 'pagina' e inserta la firma centrada ahí.
    tamano_pct: porcentaje del ancho de la página que ocupará la firma (0-100).
    """
    pw = pagina.rect.width

    # Calcular dimensiones de la firma
    img_pil = Image.open(firma_path)
    fw_pts  = pw * (tamano_pct / 100)
    fh_pts  = fw_pts * img_pil.height / img_pil.width

    # Detectar espacio en blanco
    regiones = detectar_regiones_blanco(pagina)
    cx, cy   = elegir_posicion_firma(regiones, pagina, fh_pts)

    # Recuadro donde se insertará
    rect = fitz.Rect(cx - fw_pts / 2, cy - fh_pts / 2,
                     cx + fw_pts / 2, cy + fh_pts / 2)

    # Insertar con opacidad
    pagina.insert_image(rect, filename=firma_path,
                        overlay=True,
                        xref=0)

    return rect, regiones


# ══════════════════════════════════════════════════════════════════════════════
#  INTERFAZ GRÁFICA
# ══════════════════════════════════════════════════════════════════════════════

class ValidadorInteligente:

    def __init__(self, root: tk.Tk):
        self.root = root
        self.root.title("✍️  Validador Inteligente de Firma  –  Luvegi Ingenieros")
        self.root.configure(bg=BG_DARK)
        self.root.geometry("1180x820")
        self.root.minsize(950, 680)

        # Estado
        self.firma_path     = None
        self.pdf_list       = []
        self.preview_doc    = None
        self.preview_page   = 0
        self.preview_index  = 0          # índice en pdf_list
        self._regiones_vis  = []         # regiones detectadas para el preview
        self._firma_rect_vis = None      # rect de firma en preview (canvas px)

        # Variables Tkinter
        self.var_tamano    = tk.DoubleVar(value=25.0)
        self.var_opacidad  = tk.DoubleVar(value=1.0)
        self.var_sufijo    = tk.StringVar(value="_firmado")
        self.var_status    = tk.StringVar(value="Listo. Carga una firma y tus PDFs.")
        self.var_todas_pag = tk.BooleanVar(value=True)

        self._build_ui()

    # ── Construcción de la UI ─────────────────────────────────────────────────

    def _build_ui(self):
        # Título
        tk.Label(self.root,
                 text="✍️  VALIDADOR INTELIGENTE DE FIRMA  |  LUVEGI INGENIEROS",
                 bg=BG_DARK, fg=TEXT_W, font=("Arial", 12, "bold")
                 ).pack(fill="x", pady=(10, 4), padx=14)

        main = tk.Frame(self.root, bg=BG_DARK)
        main.pack(fill="both", expand=True, padx=12, pady=(0, 8))

        # ── Panel izquierdo ───────────────────────────────────────────────────
        left = tk.Frame(main, bg=BG_MID, width=290)
        left.pack(side="left", fill="y", padx=(0, 10))
        left.pack_propagate(False)

        # 1. Firma
        self._sep(left, "1 · FIRMA")
        self._boton(left, "📂  Cargar imagen de firma", ACCENT, self._cargar_firma)
        self.lbl_firma_nombre = tk.Label(left, text="Sin firma cargada",
                                         bg=BG_MID, fg=TEXT_G,
                                         font=("Arial", 8), wraplength=250)
        self.lbl_firma_nombre.pack(anchor="w", padx=12, pady=(2, 4))
        self.canvas_mini = tk.Canvas(left, bg=BG_LIGHT, height=80,
                                     highlightthickness=0)
        self.canvas_mini.pack(fill="x", padx=12, pady=(0, 10))

        # 2. PDFs
        self._sep(left, "2 · DOCUMENTOS PDF")
        self._boton(left, "➕  Agregar PDFs", ACCENT, self._agregar_pdfs)
        self._boton(left, "🗑️   Limpiar lista", BG_LIGHT, self._limpiar_lista)

        self.lista_box = tk.Listbox(left, bg=BG_LIGHT, fg=TEXT_W,
                                    selectbackground=ACCENT,
                                    font=("Arial", 8), height=7,
                                    bd=0, highlightthickness=0)
        self.lista_box.pack(fill="x", padx=12, pady=(4, 10))
        self.lista_box.bind("<<ListboxSelect>>", self._on_select_pdf)

        # 3. Opciones
        self._sep(left, "3 · AJUSTES")

        tk.Label(left, text="Tamaño firma (% ancho de página):",
                 bg=BG_MID, fg=TEXT_G, font=("Arial", 8)).pack(anchor="w", padx=12)
        tk.Scale(left, from_=5, to=55, orient="horizontal",
                 variable=self.var_tamano, bg=BG_MID, fg=TEXT_W,
                 troughcolor=BG_LIGHT, highlightthickness=0,
                 command=self._actualizar_preview).pack(fill="x", padx=12)

        tk.Label(left, text="Opacidad:",
                 bg=BG_MID, fg=TEXT_G, font=("Arial", 8)).pack(anchor="w", padx=12, pady=(6,0))
        tk.Scale(left, from_=0.1, to=1.0, resolution=0.05, orient="horizontal",
                 variable=self.var_opacidad, bg=BG_MID, fg=TEXT_W,
                 troughcolor=BG_LIGHT, highlightthickness=0,
                 command=self._actualizar_preview).pack(fill="x", padx=12)

        tk.Checkbutton(left, text="Firmar TODAS las páginas de cada PDF",
                       variable=self.var_todas_pag,
                       bg=BG_MID, fg=TEXT_W, selectcolor=ACCENT,
                       activebackground=BG_MID,
                       font=("Arial", 8)).pack(anchor="w", padx=12, pady=(8, 0))

        tk.Label(left, text="Sufijo archivo de salida:",
                 bg=BG_MID, fg=TEXT_G, font=("Arial", 8)).pack(anchor="w", padx=12, pady=(6,0))
        tk.Entry(left, textvariable=self.var_sufijo,
                 bg=BG_LIGHT, fg=TEXT_W, insertbackground=TEXT_W,
                 font=("Arial", 8)).pack(fill="x", padx=12)

        # Botón principal
        tk.Frame(left, bg=BG_MID, height=12).pack()
        tk.Button(left,
                  text="🚀  FIRMAR TODO EL LOTE",
                  bg=ACCENT2, fg=TEXT_W,
                  font=("Arial", 10, "bold"),
                  relief="flat", cursor="hand2", pady=14,
                  command=self._procesar_lote).pack(fill="x", padx=12, pady=4)

        # ── Panel derecho (preview) ───────────────────────────────────────────
        right = tk.Frame(main, bg=BG_DARK)
        right.pack(side="left", fill="both", expand=True)

        # Controles de navegación
        nav = tk.Frame(right, bg=BG_DARK)
        nav.pack(fill="x", pady=(0, 4))
        tk.Label(nav, text="PREVISUALIZACIÓN  (espacio detectado = recuadro cian | regiones = amarillo)",
                 bg=BG_DARK, fg=TEXT_G, font=("Arial", 8)).pack(side="left")
        self.lbl_pag = tk.Label(nav, text="–/–", bg=BG_DARK, fg=TEXT_W,
                                font=("Arial", 9))
        self.lbl_pag.pack(side="right", padx=4)
        tk.Button(nav, text="▶", bg=BG_LIGHT, fg=TEXT_W, font=("Arial", 8),
                  relief="flat", padx=6, command=self._sig_pag).pack(side="right")
        tk.Button(nav, text="◀", bg=BG_LIGHT, fg=TEXT_W, font=("Arial", 8),
                  relief="flat", padx=6, command=self._ant_pag).pack(side="right", padx=2)

        self.canvas = tk.Canvas(right, bg="#0d0f18", highlightthickness=0)
        self.canvas.pack(fill="both", expand=True)
        self.canvas.bind("<Configure>", self._actualizar_preview)

        # Barra de progreso y estado
        barra = tk.Frame(self.root, bg=BG_LIGHT, pady=5)
        barra.pack(fill="x", padx=12, pady=(0, 8))
        self.progreso = ttk.Progressbar(barra, length=220, mode="determinate")
        self.progreso.pack(side="right", padx=10)
        tk.Label(barra, textvariable=self.var_status,
                 bg=BG_LIGHT, fg=TEXT_W, font=("Arial", 9)).pack(side="left", padx=10)

    # ── Helpers UI ────────────────────────────────────────────────────────────

    def _sep(self, parent, titulo):
        tk.Label(parent, text=f"  {titulo}",
                 bg=ACCENT, fg=TEXT_W,
                 font=("Arial", 8, "bold"), anchor="w"
                 ).pack(fill="x", pady=(10, 4))

    def _boton(self, parent, texto, color, cmd):
        tk.Button(parent, text=texto, bg=color, fg=TEXT_W,
                  font=("Arial", 9), relief="flat",
                  cursor="hand2", pady=6,
                  command=cmd).pack(fill="x", padx=12, pady=2)

    # ── Carga de firma ────────────────────────────────────────────────────────

    def _cargar_firma(self):
        path = filedialog.askopenfilename(
            title="Seleccionar imagen de firma",
            filetypes=[("Imágenes", "*.png *.jpg *.jpeg *.bmp"),
                       ("Todos", "*.*")])
        if not path:
            return
        try:
            img = Image.open(path).convert("RGBA")
            self.firma_path = path
            self.lbl_firma_nombre.config(text=os.path.basename(path), fg=TEXT_W)
            thumb = img.copy()
            thumb.thumbnail((250, 70))
            self._tk_mini = ImageTk.PhotoImage(thumb)
            self.canvas_mini.delete("all")
            self.canvas_mini.create_image(135, 40, image=self._tk_mini)
            self._actualizar_preview()
        except Exception as e:
            messagebox.showerror("Error", f"No se pudo cargar la imagen:\n{e}")

    # ── Gestión de PDFs ───────────────────────────────────────────────────────

    def _agregar_pdfs(self):
        paths = filedialog.askopenfilenames(
            title="Seleccionar PDFs",
            filetypes=[("PDF", "*.pdf"), ("Todos", "*.*")])
        for p in paths:
            if p not in self.pdf_list:
                self.pdf_list.append(p)
                self.lista_box.insert("end", f"  {os.path.basename(p)}")
        if self.pdf_list and self.preview_doc is None:
            self._abrir_preview(0)

    def _limpiar_lista(self):
        self.pdf_list.clear()
        self.lista_box.delete(0, "end")
        self.preview_doc = None
        self.canvas.delete("all")
        self.lbl_pag.config(text="–/–")

    def _on_select_pdf(self, _):
        sel = self.lista_box.curselection()
        if sel:
            self._abrir_preview(sel[0])

    def _abrir_preview(self, index: int):
        try:
            self.preview_doc   = fitz.open(self.pdf_list[index])
            self.preview_index = index
            self.preview_page  = 0
            self._actualizar_preview()
        except Exception as e:
            messagebox.showerror("Error", f"No se pudo abrir el PDF:\n{e}")

    # ── Previsualización ──────────────────────────────────────────────────────

    def _actualizar_preview(self, *_):
        if not self.preview_doc:
            return

        total = len(self.preview_doc)
        self.lbl_pag.config(text=f"Pág. {self.preview_page + 1} / {total}")

        cw = self.canvas.winfo_width()
        ch = self.canvas.winfo_height()
        if cw < 50 or ch < 50:
            return

        pagina = self.preview_doc[self.preview_page]
        pw, ph = pagina.rect.width, pagina.rect.height
        scale  = min(cw / pw, ch / ph) * 0.95

        # Renderizar página
        pix = pagina.get_pixmap(matrix=fitz.Matrix(scale, scale), alpha=False)
        img = Image.frombytes("RGB", [pix.width, pix.height], pix.samples)

        ox = (cw - img.width)  // 2
        oy = (ch - img.height) // 2

        # ── Superponer firma si existe ────────────────────────────────────────
        regiones = []
        firma_cx = firma_cy = None

        if self.firma_path:
            try:
                firma_pil = Image.open(self.firma_path).convert("RGBA")
                fw_pts    = pw * (self.var_tamano.get() / 100)
                fh_pts    = fw_pts * firma_pil.height / firma_pil.width

                regiones = detectar_regiones_blanco(pagina)
                firma_cx, firma_cy = elegir_posicion_firma(regiones, pagina, fh_pts)

                # Redimensionar firma
                fw_px = max(1, int(fw_pts * scale))
                fh_px = max(1, int(fh_pts * scale))
                firma_r = firma_pil.copy().resize((fw_px, fh_px), Image.LANCZOS)

                # Aplicar opacidad
                op = int(self.var_opacidad.get() * 255)
                r, g, b, a = firma_r.split()
                a = a.point(lambda x: int(x * op / 255))
                firma_r.putalpha(a)

                fx_px = ox + int((firma_cx - fw_pts / 2) * scale)
                fy_px = oy + int((firma_cy - fh_pts / 2) * scale)

                try:
                    img.paste(firma_r, (fx_px, fy_px), firma_r)
                except Exception:
                    img.paste(firma_r, (fx_px, fy_px))

                self._firma_rect_vis = (fx_px, fy_px, fw_px, fh_px)
            except Exception:
                self._firma_rect_vis = None
        else:
            self._firma_rect_vis = None

        self._tk_preview = ImageTk.PhotoImage(img)
        self.canvas.delete("all")
        self.canvas.create_image(ox, oy, anchor="nw", image=self._tk_preview)

        # ── Dibujar regiones en blanco (amarillo semitransparente) ────────────
        for r in regiones:
            y0c = oy + int(r["y0"] * scale)
            y1c = oy + int(r["y1"] * scale)
            x0c = ox + int(pw * 0.03 * scale)
            x1c = ox + int(pw * 0.97 * scale)
            self.canvas.create_rectangle(x0c, y0c, x1c, y1c,
                                         outline="#f0c040", width=1,
                                         dash=(5, 4))

        # ── Dibujar recuadro de firma detectada (cian) ────────────────────────
        if self._firma_rect_vis:
            x, y, w, h = self._firma_rect_vis
            self.canvas.create_rectangle(x, y, x + w, y + h,
                                         outline=CYAN, width=2)
            self.canvas.create_text(x + 4, y - 14, anchor="nw",
                                    text="▶ Posición detectada automáticamente",
                                    fill=CYAN, font=("Arial", 8))

    def _ant_pag(self):
        if self.preview_doc and self.preview_page > 0:
            self.preview_page -= 1
            self._actualizar_preview()

    def _sig_pag(self):
        if self.preview_doc and self.preview_page < len(self.preview_doc) - 1:
            self.preview_page += 1
            self._actualizar_preview()

    # ── Procesamiento del lote ────────────────────────────────────────────────

    def _procesar_lote(self):
        if not self.firma_path:
            messagebox.showwarning("Falta firma", "Carga primero una imagen de firma.")
            return
        if not self.pdf_list:
            messagebox.showwarning("Sin PDFs", "Agrega al menos un PDF.")
            return

        total     = len(self.pdf_list)
        exitosos  = []
        errores   = []
        self.progreso["maximum"] = total
        self.progreso["value"]   = 0

        for i, pdf_path in enumerate(self.pdf_list):
            nombre = os.path.basename(pdf_path)
            self.var_status.set(f"Procesando {i+1}/{total}: {nombre}")
            self.root.update()

            try:
                doc = fitz.open(pdf_path)
                paginas = range(len(doc)) if self.var_todas_pag.get() else [0]

                for np in paginas:
                    pagina = doc[np]
                    pw     = pagina.rect.width

                    firma_pil = Image.open(self.firma_path)
                    fw_pts    = pw * (self.var_tamano.get() / 100)
                    fh_pts    = fw_pts * firma_pil.height / firma_pil.width

                    regiones         = detectar_regiones_blanco(pagina)
                    firma_cx, firma_cy = elegir_posicion_firma(regiones, pagina, fh_pts)

                    rect = fitz.Rect(firma_cx - fw_pts / 2,
                                     firma_cy - fh_pts / 2,
                                     firma_cx + fw_pts / 2,
                                     firma_cy + fh_pts / 2)

                    pagina.insert_image(rect, filename=self.firma_path, overlay=True)

                base, ext = os.path.splitext(pdf_path)
                out_path  = base + self.var_sufijo.get() + ext
                doc.save(out_path)
                doc.close()
                exitosos.append(out_path)

            except Exception as e:
                errores.append(f"{nombre}: {e}")

            self.progreso["value"] = i + 1
            self.root.update()

        self.var_status.set(f"✅ Completado — {len(exitosos)} PDF(s) firmados.")

        # Resumen final
        msg = f"✅  Firmados correctamente: {len(exitosos)}\n"
        if exitosos:
            msg += "\nArchivos generados:\n"
            msg += "\n".join(f"  • {os.path.basename(p)}" for p in exitosos)
        if errores:
            msg += f"\n\n⚠️  Errores ({len(errores)}):\n" + "\n".join(errores)

        messagebox.showinfo("Luvegi — Proceso terminado", msg)


# ══════════════════════════════════════════════════════════════════════════════
#  ENTRY POINT
# ══════════════════════════════════════════════════════════════════════════════

if __name__ == "__main__":
    root = tk.Tk()
    app  = ValidadorInteligente(root)
    root.mainloop()