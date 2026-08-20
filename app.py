import os
import subprocess
import sys
import threading
import time
import tkinter as tk
from datetime import datetime
from tkinter import filedialog, messagebox, simpledialog

from pypdf import PdfReader, PdfWriter

# ==========================================
# PALETTE & DESIGN SYSTEM (Modern macOS / Clean SaaS)
# ==========================================
COLORS = {
    "bg_main": "#F1F5F9",  # Slate 100
    "card_bg": "#FFFFFF",  # Pure white
    "card_border": "#E2E8F0",  # Slate 200
    "card_hover": "#F8FAFC",  # Slate 50
    "primary": "#2563EB",  # Blue 600
    "primary_hover": "#1D4ED8",  # Blue 700
    "primary_active": "#1E40AF",  # Blue 800
    "primary_light": "#EFF6FF",  # Blue 50
    "primary_border": "#BFDBFE",  # Blue 200
    "success": "#059669",  # Emerald 600
    "success_light": "#ECFDF5",  # Emerald 50
    "success_border": "#A7F3D0",  # Emerald 200
    "text_dark": "#0F172A",  # Slate 900
    "text_medium": "#334155",  # Slate 700
    "text_muted": "#64748B",  # Slate 500
    "text_light": "#94A3B8",  # Slate 400
    "danger": "#EF4444",  # Red 500
    "terminal_bg": "#0F172A",  # Slate 900 Dark terminal
    "terminal_fg": "#F8FAFC",  # Slate 50
    # Màu sắc các dải phần tách
    "part_colors": [
        "#3B82F6",  # Phần 1: Blue
        "#8B5CF6",  # Phần 2: Purple
        "#10B981",  # Phần 3: Emerald
        "#F59E0B",  # Phần 4: Amber
        "#EC4899",  # Phần 5: Pink
        "#06B6D4",  # Phần 6: Cyan
        "#6366F1",  # Phần 7: Indigo
        "#14B8A6",  # Phần 8: Teal
    ],
}

FONTS = {
    "title": ("Helvetica Neue", 16, "bold"),
    "subtitle": ("Helvetica Neue", 10),
    "section": ("Helvetica Neue", 11, "bold"),
    "body": ("Helvetica Neue", 10),
    "body_bold": ("Helvetica Neue", 10, "bold"),
    "small": ("Helvetica Neue", 9),
    "small_bold": ("Helvetica Neue", 9, "bold"),
    "mono": ("Menlo", 9),
    "mono_bold": ("Menlo", 9, "bold"),
}


# ==========================================
# CUSTOM UI WIDGETS
# ==========================================
class ModernButton(tk.Canvas):
    """Nút bấm bo góc hiện đại với hiệu ứng hover và click mượt mà."""

    def __init__(
        self,
        parent,
        text,
        command=None,
        width=120,
        height=34,
        bg_color=COLORS["primary"],
        hover_color=COLORS["primary_hover"],
        text_color="#FFFFFF",
        font=FONTS["body_bold"],
        radius=8,
        icon="",
    ):
        super().__init__(
            parent,
            width=width,
            height=height,
            bg=parent["bg"],
            highlightthickness=0,
            bd=0,
            cursor="hand2",
        )
        self.text = f"{icon} {text}".strip() if icon else text
        self.command = command
        self.width = width
        self.height = height
        self.bg_color = bg_color
        self.hover_color = hover_color
        self.text_color = text_color
        self.font = font
        self.radius = radius
        self.current_bg = bg_color
        self.state_disabled = False

        self._draw()
        self.bind("<Enter>", self._on_enter)
        self.bind("<Leave>", self._on_leave)
        self.bind("<Button-1>", self._on_click)

    def _draw(self):
        self.delete("all")
        r = self.radius
        self._round_rect(
            1, 1, self.width - 2, self.height - 2, r, fill=self.current_bg, outline=""
        )
        self.create_text(
            self.width // 2,
            self.height // 2,
            text=self.text,
            fill=self.text_color,
            font=self.font,
        )

    def _round_rect(self, x1, y1, x2, y2, r, **kwargs):
        points = [
            x1 + r,
            y1,
            x2 - r,
            y1,
            x2,
            y1,
            x2,
            y1 + r,
            x2,
            y2 - r,
            x2,
            y2,
            x2 - r,
            y2,
            x1 + r,
            y2,
            x1,
            y2,
            x1,
            y2 - r,
            x1,
            y1 + r,
            x1,
            y1,
        ]
        return self.create_polygon(points, smooth=True, **kwargs)

    def _on_enter(self, e):
        if not self.state_disabled:
            self.current_bg = self.hover_color
            self._draw()

    def _on_leave(self, e):
        if not self.state_disabled:
            self.current_bg = self.bg_color
            self._draw()

    def _on_click(self, e):
        if not self.state_disabled and self.command:
            self.command()

    def set_state(self, state):
        if state == "disabled":
            self.state_disabled = True
            self.current_bg = "#CBD5E1"
            self.config(cursor="arrow")
        else:
            self.state_disabled = False
            self.current_bg = self.bg_color
            self.config(cursor="hand2")
        self._draw()

    def set_colors(self, bg_color, hover_color):
        self.bg_color = bg_color
        self.hover_color = hover_color
        self.current_bg = bg_color
        self._draw()


class ModernEntry(tk.Frame):
    """Input field hiện đại với viền bo và trạng thái focus."""

    def __init__(
        self,
        parent,
        textvariable=None,
        placeholder="",
        state="normal",
        width=None,
        **kwargs,
    ):
        super().__init__(parent, bg=COLORS["card_border"], padx=1, pady=1, **kwargs)
        self.state_str = state
        self.entry_frame = tk.Frame(self, bg="#FFFFFF", padx=8, pady=4)
        self.entry_frame.pack(fill="both", expand=True)

        self.entry = tk.Entry(
            self.entry_frame,
            textvariable=textvariable,
            font=FONTS["body"],
            bg="#FFFFFF",
            fg=COLORS["text_dark"],
            bd=0,
            relief="flat",
            highlightthickness=0,
            width=width,
        )
        if state == "readonly":
            self.entry.config(state="readonly", readonlybackground="#FFFFFF")
        self.entry.pack(fill="both", expand=True)

        self.entry.bind("<FocusIn>", self._on_focus_in)
        self.entry.bind("<FocusOut>", self._on_focus_out)

    def _on_focus_in(self, e):
        if self.state_str != "readonly":
            self.config(bg=COLORS["primary"])

    def _on_focus_out(self, e):
        self.config(bg=COLORS["card_border"])

    def get(self):
        return self.entry.get()


class MultiSegmentVisualizer(tk.Canvas):
    """Thanh trực quan hoá tỉ lệ phân chia sách đa đoạn."""

    def __init__(self, parent, **kwargs):
        super().__init__(
            parent,
            height=34,
            bg=COLORS["card_bg"],
            highlightthickness=0,
            bd=0,
            **kwargs,
        )
        self.parts_info = []  # List of (part_num, start_page, end_page, page_count, color)
        self.total_pages = 0
        self.bind("<Configure>", lambda e: self.redraw())

    def update_parts(self, parts_info, total_pages):
        self.parts_info = parts_info
        self.total_pages = total_pages
        self.redraw()

    def redraw(self):
        self.delete("all")
        w = self.winfo_width()
        h = self.winfo_height()
        if w < 20 or h < 10:
            return

        if self.total_pages <= 0 or not self.parts_info:
            self.create_rectangle(0, 4, w, h - 4, fill="#F1F5F9", outline="#E2E8F0")
            self.create_text(
                w // 2,
                h // 2,
                text="Chưa có thông tin sách để hiển thị tỷ lệ chia",
                fill=COLORS["text_light"],
                font=FONTS["small"],
            )
            return

        current_x = 0
        total_covered = sum(p[3] for p in self.parts_info)
        base_total = max(self.total_pages, total_covered)

        for i, (part_num, start_p, end_p, count, color) in enumerate(self.parts_info):
            ratio = count / base_total
            seg_w = max(1, int(w * ratio))
            if i == len(self.parts_info) - 1:
                end_x = w
            else:
                end_x = current_x + seg_w

            self.create_rectangle(
                current_x,
                4,
                end_x - (2 if i < len(self.parts_info) - 1 else 0),
                h - 4,
                fill=color,
                outline="",
            )

            seg_mid_x = (current_x + end_x) // 2
            pct = int((count / self.total_pages) * 100) if self.total_pages > 0 else 0
            if (end_x - current_x) > 60:
                self.create_text(
                    seg_mid_x,
                    h // 2,
                    text=f"P{part_num}: {count}tr ({pct}%)",
                    fill="#FFFFFF",
                    font=FONTS["small_bold"],
                )
            elif (end_x - current_x) > 30:
                self.create_text(
                    seg_mid_x,
                    h // 2,
                    text=f"P{part_num}",
                    fill="#FFFFFF",
                    font=FONTS["small_bold"],
                )

            current_x = end_x


# ==========================================
# MAIN APPLICATION
# ==========================================
class PdfSplitterApp(tk.Tk):
    def __init__(self):
        super().__init__()

        self.title("Sách PDF Pro — Chia Theo Phần & Chia Theo Trang")
        self.geometry("820x900")
        self.minsize(740, 780)
        self.configure(bg=COLORS["bg_main"])

        # Dữ liệu trạng thái
        self.pdf_path = tk.StringVar()
        self.output_dir = tk.StringVar()
        self.total_pages = 0

        # Chế độ phân chia: 'by_parts' (chia theo số phần) | 'by_pages' (chia theo mốc trang)
        self.split_mode = tk.StringVar(value="by_parts")
        self.split_parts_count = tk.IntVar(value=2)

        # Danh sách cấu hình các phần tuỳ chỉnh trang: list of dict {start_var, end_var, name_var}
        self.custom_ranges = []

        # Dữ liệu các phần đã tính toán sẵn sàng xuất: list of dict
        self.calculated_parts = []

        # Quản lý folder
        self.create_subfolder = tk.BooleanVar(value=True)
        self.subfolder_name = tk.StringVar(value="Sach_Da_Tach")
        self.ask_before_create_dir = tk.BooleanVar(value=True)

        self.is_processing = False

        self._build_ui()

    def _build_ui(self):
        # Header banner
        header_bar = tk.Frame(
            self,
            bg="#FFFFFF",
            padx=28,
            pady=16,
            highlightbackground=COLORS["card_border"],
            highlightthickness=1,
        )
        header_bar.pack(fill="x")

        head_content = tk.Frame(header_bar, bg="#FFFFFF")
        head_content.pack(fill="x")

        icon_lbl = tk.Label(
            head_content, text="📚", font=("Helvetica Neue", 26), bg="#FFFFFF"
        )
        icon_lbl.pack(side="left", padx=(0, 14))

        title_col = tk.Frame(head_content, bg="#FFFFFF")
        title_col.pack(side="left", fill="y")

        lbl_title = tk.Label(
            title_col,
            text="Quản Lý & Xuất Sách PDF",
            font=FONTS["title"],
            fg=COLORS["text_dark"],
            bg="#FFFFFF",
        )
        lbl_title.pack(anchor="w")

        lbl_subtitle = tk.Label(
            title_col,
            text="Tùy chọn linh hoạt: Chia đều theo số phần (2/3/4) hoặc Chia theo mốc trang tùy ý.",
            font=FONTS["subtitle"],
            fg=COLORS["text_muted"],
            bg="#FFFFFF",
        )
        lbl_subtitle.pack(anchor="w", pady=(2, 0))

        # Main scrollable/padded container
        content_frame = tk.Frame(self, bg=COLORS["bg_main"], padx=18, pady=10)
        content_frame.pack(fill="both", expand=True)

        # -------------------------------------------------------------
        # 1. CARD IMPORT SÁCH
        # -------------------------------------------------------------
        self.card_import = tk.Frame(
            content_frame,
            bg="#FFFFFF",
            padx=16,
            pady=10,
            highlightbackground=COLORS["card_border"],
            highlightthickness=1,
        )
        self.card_import.pack(fill="x", pady=(0, 8))

        step1_title = tk.Label(
            self.card_import,
            text="1. Chọn Sách PDF (Import Book)",
            font=FONTS["section"],
            fg=COLORS["text_dark"],
            bg="#FFFFFF",
        )
        step1_title.pack(anchor="w")

        row1 = tk.Frame(self.card_import, bg="#FFFFFF")
        row1.pack(fill="x", pady=(6, 6))

        self.entry_pdf = ModernEntry(row1, textvariable=self.pdf_path, state="readonly")
        self.entry_pdf.pack(side="left", fill="x", expand=True, padx=(0, 10))

        self.btn_browse_pdf = ModernButton(
            row1,
            text="Chọn File PDF",
            icon="📂",
            width=130,
            height=34,
            bg_color=COLORS["primary"],
            hover_color=COLORS["primary_hover"],
            command=self.browse_pdf_file,
        )
        self.btn_browse_pdf.pack(side="right")

        # Badges thông tin sách
        self.info_badge_frame = tk.Frame(self.card_import, bg="#FFFFFF")
        self.info_badge_frame.pack(fill="x", pady=(2, 0))

        self.lbl_book_name = tk.Label(
            self.info_badge_frame,
            text="📄 Chưa chọn file",
            font=FONTS["small"],
            fg=COLORS["text_muted"],
            bg="#F8FAFC",
            padx=8,
            pady=3,
        )
        self.lbl_book_name.pack(side="left", padx=(0, 6))

        self.lbl_book_pages = tk.Label(
            self.info_badge_frame,
            text="📑 0 trang",
            font=FONTS["small_bold"],
            fg=COLORS["primary"],
            bg=COLORS["primary_light"],
            padx=8,
            pady=3,
        )
        self.lbl_book_pages.pack(side="left", padx=(0, 6))

        self.lbl_book_size = tk.Label(
            self.info_badge_frame,
            text="💾 0 MB",
            font=FONTS["small"],
            fg=COLORS["text_muted"],
            bg="#F8FAFC",
            padx=8,
            pady=3,
        )
        self.lbl_book_size.pack(side="left")

        # -------------------------------------------------------------
        # 2. CARD TÙY CHỌN PHÂN CHIA (CHIA THEO PHẦN HOẶC CHIA THEO TRANG)
        # -------------------------------------------------------------
        self.card_split = tk.Frame(
            content_frame,
            bg="#FFFFFF",
            padx=16,
            pady=10,
            highlightbackground=COLORS["card_border"],
            highlightthickness=1,
        )
        self.card_split.pack(fill="x", pady=(0, 8))

        step2_header = tk.Frame(self.card_split, bg="#FFFFFF")
        step2_header.pack(fill="x", pady=(0, 6))

        step2_title = tk.Label(
            step2_header,
            text="2. Tùy Chọn Phương Thức Phân Chia",
            font=FONTS["section"],
            fg=COLORS["text_dark"],
            bg="#FFFFFF",
        )
        step2_title.pack(side="left")

        # Radio Switcher giữa 2 chế độ
        mode_switcher_frame = tk.Frame(
            self.card_split,
            bg="#F1F5F9",
            padx=6,
            pady=4,
            highlightbackground="#E2E8F0",
            highlightthickness=1,
        )
        mode_switcher_frame.pack(fill="x", pady=(0, 8))

        self.rb_by_parts = tk.Radiobutton(
            mode_switcher_frame,
            text="⚡ Chế độ 1: Chia Đều Theo Số Phần (2 / 3 / 4 phần)",
            variable=self.split_mode,
            value="by_parts",
            font=FONTS["body_bold"],
            bg="#F1F5F9",
            fg=COLORS["text_dark"],
            activebackground="#F1F5F9",
            command=self.on_split_mode_changed,
        )
        self.rb_by_parts.pack(side="left", padx=(6, 20))

        self.rb_by_pages = tk.Radiobutton(
            mode_switcher_frame,
            text="📑 Chế độ 2: Chia Theo Mốc Trang / Phạm Vi Tùy Ý",
            variable=self.split_mode,
            value="by_pages",
            font=FONTS["body_bold"],
            bg="#F1F5F9",
            fg=COLORS["text_dark"],
            activebackground="#F1F5F9",
            command=self.on_split_mode_changed,
        )
        self.rb_by_pages.pack(side="left")

        # Container điều khiển riêng cho từng chế độ
        self.mode_control_container = tk.Frame(self.card_split, bg="#FFFFFF")
        self.mode_control_container.pack(fill="x", pady=(0, 6))

        # Thanh trực quan hoá tỉ lệ phân chia đa đoạn
        self.visualizer = MultiSegmentVisualizer(self.card_split)
        self.visualizer.pack(fill="x", pady=(4, 6))

        # Bảng danh sách các phần được sinh ra
        self.parts_preview_container = tk.Frame(
            self.card_split,
            bg="#F8FAFC",
            padx=8,
            pady=6,
            highlightbackground="#E2E8F0",
            highlightthickness=1,
        )
        self.parts_preview_container.pack(fill="x")

        # -------------------------------------------------------------
        # 3. CARD CHỌN ĐƯỜNG DẪN LƯU & QUẢN LÝ FOLDER
        # -------------------------------------------------------------
        self.card_export = tk.Frame(
            content_frame,
            bg="#FFFFFF",
            padx=16,
            pady=10,
            highlightbackground=COLORS["card_border"],
            highlightthickness=1,
        )
        self.card_export.pack(fill="x", pady=(0, 8))

        step3_title = tk.Label(
            self.card_export,
            text="3. Chọn Đường Dẫn Lưu & Quản Lý Thư Mục (Save Folder)",
            font=FONTS["section"],
            fg=COLORS["text_dark"],
            bg="#FFFFFF",
        )
        step3_title.pack(anchor="w")

        dir_row = tk.Frame(self.card_export, bg="#FFFFFF")
        dir_row.pack(fill="x", pady=(6, 6))

        self.entry_dir = ModernEntry(dir_row, textvariable=self.output_dir)
        self.entry_dir.pack(side="left", fill="x", expand=True, padx=(0, 8))

        self.btn_browse_dir = ModernButton(
            dir_row,
            text="Chọn Thư Mục",
            icon="📁",
            width=120,
            height=34,
            bg_color="#475569",
            hover_color="#334155",
            command=self.browse_output_dir,
        )
        self.btn_browse_dir.pack(side="left", padx=(0, 6))

        self.btn_new_folder = ModernButton(
            dir_row,
            text="Tạo Folder",
            icon="➕",
            width=100,
            height=34,
            bg_color="#0284C7",
            hover_color="#0369A1",
            command=self.prompt_create_folder_manually,
        )
        self.btn_new_folder.pack(side="right")

        # Tuỳ chọn tạo Subfolder
        folder_opt_row = tk.Frame(
            self.card_export,
            bg="#F8FAFC",
            padx=8,
            pady=6,
            highlightbackground="#E2E8F0",
            highlightthickness=1,
        )
        folder_opt_row.pack(fill="x")

        cb_subfolder = tk.Checkbutton(
            folder_opt_row,
            text="Gom vào thư mục con riêng:",
            variable=self.create_subfolder,
            font=FONTS["body_bold"],
            bg="#F8FAFC",
            fg=COLORS["text_dark"],
            activebackground="#F8FAFC",
        )
        cb_subfolder.pack(side="left", padx=(0, 8))

        self.entry_subfolder = ModernEntry(
            folder_opt_row, textvariable=self.subfolder_name
        )
        self.entry_subfolder.pack(side="left", fill="x", expand=True, padx=(0, 10))

        cb_ask = tk.Checkbutton(
            folder_opt_row,
            text="Hỏi xác nhận khi tạo",
            variable=self.ask_before_create_dir,
            font=FONTS["small"],
            bg="#F8FAFC",
            fg=COLORS["text_muted"],
            activebackground="#F8FAFC",
        )
        cb_ask.pack(side="right")

        # -------------------------------------------------------------
        # 4. CARD TIẾN TRÌNH & NHẬT KÝ (LIVE PROCESS)
        # -------------------------------------------------------------
        self.card_process = tk.Frame(
            content_frame,
            bg="#FFFFFF",
            padx=16,
            pady=10,
            highlightbackground=COLORS["card_border"],
            highlightthickness=1,
        )
        self.card_process.pack(fill="both", expand=True, pady=(0, 6))

        proc_header = tk.Frame(self.card_process, bg="#FFFFFF")
        proc_header.pack(fill="x", pady=(0, 4))

        step4_title = tk.Label(
            proc_header,
            text="4. Tiến Trình Xử Lý (Live Process)",
            font=FONTS["section"],
            fg=COLORS["text_dark"],
            bg="#FFFFFF",
        )
        step4_title.pack(side="left")

        self.lbl_percentage = tk.Label(
            proc_header,
            text="0%",
            font=FONTS["body_bold"],
            fg=COLORS["primary"],
            bg=COLORS["primary_light"],
            padx=8,
            pady=2,
        )
        self.lbl_percentage.pack(side="right")

        self.lbl_process_step = tk.Label(
            proc_header,
            text="Đang chờ...",
            font=FONTS["small"],
            fg=COLORS["text_muted"],
            bg="#FFFFFF",
        )
        self.lbl_process_step.pack(side="right", padx=(0, 10))

        # Progress bar
        self.progress_canvas = tk.Canvas(
            self.card_process, height=8, bg="#E2E8F0", highlightthickness=0, bd=0
        )
        self.progress_canvas.pack(fill="x", pady=(0, 6))

        # Console Log
        log_frame = tk.Frame(
            self.card_process, bg=COLORS["terminal_bg"], padx=6, pady=6
        )
        log_frame.pack(fill="both", expand=True)

        self.log_text = tk.Text(
            log_frame,
            bg=COLORS["terminal_bg"],
            fg=COLORS["terminal_fg"],
            font=FONTS["mono"],
            height=4,
            wrap="word",
            bd=0,
            highlightthickness=0,
        )
        self.log_text.pack(side="left", fill="both", expand=True)

        scrollbar = tk.Scrollbar(
            log_frame, command=self.log_text.yview, bg=COLORS["terminal_bg"]
        )
        scrollbar.pack(side="right", fill="y")
        self.log_text.config(yscrollcommand=scrollbar.set)

        self.add_log("Hệ thống sẵn sàng. Vui lòng chọn sách PDF để bắt đầu.")

        # -------------------------------------------------------------
        # 5. BOTTOM ACTION BAR
        # -------------------------------------------------------------
        bottom_frame = tk.Frame(content_frame, bg=COLORS["bg_main"])
        bottom_frame.pack(fill="x")

        self.lbl_status = tk.Label(
            bottom_frame,
            text="● Sẵn sàng thực hiện",
            font=FONTS["body"],
            fg=COLORS["text_muted"],
            bg=COLORS["bg_main"],
        )
        self.lbl_status.pack(side="left")

        self.btn_export = ModernButton(
            bottom_frame,
            text="Bắt Đầu Xuất Sách",
            icon="⚡",
            width=180,
            height=38,
            radius=10,
            bg_color=COLORS["success"],
            hover_color="#047857",
            font=("Helvetica Neue", 11, "bold"),
            command=self.start_export_thread,
        )
        self.btn_export.pack(side="right")

        # Khởi tạo giao diện chế độ mặc định
        self.render_mode_controls()

    # ==========================================
    # QUẢN LÝ 2 CHẾ ĐỘ PHÂN CHIA (MODE SWITCHING)
    # ==========================================
    def on_split_mode_changed(self):
        self.render_mode_controls()
        self.refresh_split_calculation()

    def render_mode_controls(self):
        """Vẽ lại bảng điều khiển theo chế độ được chọn."""
        for widget in self.mode_control_container.winfo_children():
            widget.destroy()

        mode = self.split_mode.get()

        if mode == "by_parts":
            # --- CHẾ ĐỘ 1: CHIA THEO SỐ PHẦN ---
            f = tk.Frame(self.mode_control_container, bg="#FFFFFF")
            f.pack(fill="x", pady=2)

            tk.Label(
                f,
                text="Chọn số phần chia đều:",
                font=FONTS["body_bold"],
                fg=COLORS["text_medium"],
                bg="#FFFFFF",
            ).pack(side="left", padx=(0, 10))

            k = self.split_parts_count.get()
            self.btn_part2 = ModernButton(
                f,
                text="2 Phần",
                icon="✂️",
                width=95,
                height=30,
                bg_color=COLORS["primary"] if k == 2 else "#64748B",
                hover_color=COLORS["primary_hover"] if k == 2 else "#475569",
                command=lambda: self.select_parts_count(2),
            )
            self.btn_part2.pack(side="left", padx=(0, 6))

            self.btn_part3 = ModernButton(
                f,
                text="3 Phần",
                icon="✂️",
                width=95,
                height=30,
                bg_color=COLORS["primary"] if k == 3 else "#64748B",
                hover_color=COLORS["primary_hover"] if k == 3 else "#475569",
                command=lambda: self.select_parts_count(3),
            )
            self.btn_part3.pack(side="left", padx=(0, 6))

            self.btn_part4 = ModernButton(
                f,
                text="4 Phần",
                icon="✂️",
                width=95,
                height=30,
                bg_color=COLORS["primary"] if k == 4 else "#64748B",
                hover_color=COLORS["primary_hover"] if k == 4 else "#475569",
                command=lambda: self.select_parts_count(4),
            )
            self.btn_part4.pack(side="left", padx=(0, 10))

            tk.Label(
                f,
                text="Hoặc nhập số phần:",
                font=FONTS["small"],
                fg=COLORS["text_muted"],
                bg="#FFFFFF",
            ).pack(side="left", padx=(0, 4))
            self.spin_custom_parts = tk.Spinbox(
                f,
                from_=2,
                to=20,
                textvariable=self.split_parts_count,
                width=4,
                font=FONTS["body_bold"],
                command=self.refresh_split_calculation,
            )
            self.spin_custom_parts.pack(side="left")
            self.spin_custom_parts.bind(
                "<KeyRelease>", lambda e: self.refresh_split_calculation()
            )

        else:
            # --- CHẾ ĐỘ 2: CHIA THEO MỐC TRANG TÙY CHỌN ---
            f = tk.Frame(self.mode_control_container, bg="#FFFFFF")
            f.pack(fill="x", pady=2)

            tk.Label(
                f,
                text="Thiết lập các khoảng trang cần cắt:",
                font=FONTS["body_bold"],
                fg=COLORS["text_medium"],
                bg="#FFFFFF",
            ).pack(side="left", padx=(0, 10))

            btn_add = ModernButton(
                f,
                text="Thêm Phần",
                icon="➕",
                width=110,
                height=30,
                bg_color="#0284C7",
                hover_color="#0369A1",
                command=self.add_custom_range_row,
            )
            btn_add.pack(side="left", padx=(0, 6))

            btn_reset = ModernButton(
                f,
                text="Tự động lấp đầy",
                icon="🔄",
                width=125,
                height=30,
                bg_color="#475569",
                hover_color="#334155",
                command=self.auto_fill_ranges_from_total,
            )
            btn_reset.pack(side="left")

    def select_parts_count(self, count):
        self.split_parts_count.set(count)
        self.render_mode_controls()
        self.refresh_split_calculation()

    # ==========================================
    # TÍNH TOÁN & CẬP NHẬT CÁC PHẦN (CALCULATION)
    # ==========================================
    def refresh_split_calculation(self):
        mode = self.split_mode.get()
        total = self.total_pages

        for widget in self.parts_preview_container.winfo_children():
            widget.destroy()

        if total <= 0:
            tk.Label(
                self.parts_preview_container,
                text="Vui lòng chọn file PDF để cấu hình phân chia sách.",
                font=FONTS["small"],
                fg=COLORS["text_muted"],
                bg="#F8FAFC",
            ).pack(anchor="w", pady=4)
            self.visualizer.update_parts([], 0)
            self.calculated_parts = []
            return

        base_name = ""
        if self.pdf_path.get():
            base_name, _ = os.path.splitext(os.path.basename(self.pdf_path.get()))

        self.calculated_parts = []
        visualizer_parts = []

        if mode == "by_parts":
            # --- TÍNH TOÁN THEO SỐ PHẦN (2/3/4/N) ---
            k = max(2, self.split_parts_count.get())
            base_pages = total // k
            remainder = total % k
            current_page = 1

            for i in range(k):
                p_num = i + 1
                count = base_pages + (1 if i < remainder else 0)
                start_p = current_page
                end_p = current_page + count - 1
                current_page = end_p + 1
                color = COLORS["part_colors"][i % len(COLORS["part_colors"])]
                fn = (
                    f"{base_name}_part{p_num}.pdf" if base_name else f"phan_{p_num}.pdf"
                )
                fn_var = tk.StringVar(value=fn)

                p_data = {
                    "part_num": p_num,
                    "start": start_p,
                    "end": end_p,
                    "count": count,
                    "color": color,
                    "filename_var": fn_var,
                }
                self.calculated_parts.append(p_data)
                visualizer_parts.append((p_num, start_p, end_p, count, color))

            self._render_parts_table(editable_ranges=False)

        else:
            # --- TÍNH TOÁN THEO MỐC TRANG TÙY CHỌN ---
            if not self.custom_ranges:
                self.init_default_custom_ranges()

            for i, item in enumerate(self.custom_ranges):
                p_num = i + 1
                try:
                    start_p = int(item["start_var"].get())
                except ValueError:
                    start_p = 1
                try:
                    end_p = int(item["end_var"].get())
                except ValueError:
                    end_p = total

                start_p = max(1, min(start_p, total))
                end_p = max(start_p, min(end_p, total))
                count = end_p - start_p + 1
                color = COLORS["part_colors"][i % len(COLORS["part_colors"])]

                p_data = {
                    "part_num": p_num,
                    "start": start_p,
                    "end": end_p,
                    "count": count,
                    "color": color,
                    "filename_var": item["name_var"],
                }
                self.calculated_parts.append(p_data)
                visualizer_parts.append((p_num, start_p, end_p, count, color))

            self._render_parts_table(editable_ranges=True)

        self.visualizer.update_parts(visualizer_parts, total)

    def _render_parts_table(self, editable_ranges=False):
        """Vẽ bảng danh sách các phần ra UI."""
        grid_frame = tk.Frame(self.parts_preview_container, bg="#F8FAFC")
        grid_frame.pack(fill="x")

        for idx, p in enumerate(self.calculated_parts):
            row = tk.Frame(grid_frame, bg="#F8FAFC")
            row.pack(fill="x", pady=2)

            # Badge màu phần
            badge_lbl = tk.Label(
                row,
                text=f" Phần {p['part_num']} ",
                font=FONTS["small_bold"],
                fg="#FFFFFF",
                bg=p["color"],
                padx=6,
                pady=2,
            )
            badge_lbl.pack(side="left", padx=(0, 6))

            if editable_ranges:
                # Chế độ chỉnh sửa số trang từng phần
                cr = self.custom_ranges[idx]
                tk.Label(
                    row,
                    text="Từ trang:",
                    font=FONTS["small"],
                    fg=COLORS["text_medium"],
                    bg="#F8FAFC",
                ).pack(side="left", padx=(0, 2))
                s_entry = ModernEntry(row, textvariable=cr["start_var"], width=4)
                s_entry.pack(side="left", padx=(0, 4))
                s_entry.entry.bind(
                    "<KeyRelease>", lambda e: self.refresh_split_calculation()
                )

                tk.Label(
                    row,
                    text="➔ Đến trang:",
                    font=FONTS["small"],
                    fg=COLORS["text_medium"],
                    bg="#F8FAFC",
                ).pack(side="left", padx=(0, 2))
                e_entry = ModernEntry(row, textvariable=cr["end_var"], width=4)
                e_entry.pack(side="left", padx=(0, 6))
                e_entry.entry.bind(
                    "<KeyRelease>", lambda e: self.refresh_split_calculation()
                )

                count_lbl = tk.Label(
                    row,
                    text=f"({p['count']} tr)",
                    font=FONTS["small_bold"],
                    fg=COLORS["primary"],
                    bg="#F8FAFC",
                )
                count_lbl.pack(side="left", padx=(0, 8))

                # Nút xoá dòng nếu có hơn 1 phần
                if len(self.custom_ranges) > 1:
                    btn_del = tk.Button(
                        row,
                        text="✖",
                        font=("Helvetica", 8, "bold"),
                        fg="#EF4444",
                        bg="#F8FAFC",
                        bd=0,
                        cursor="hand2",
                        command=lambda i=idx: self.remove_custom_range_row(i),
                    )
                    btn_del.pack(side="right", padx=(4, 0))
            else:
                # Chế độ xem thông tin tự động
                info_text = f"Trang {p['start']} ➔ {p['end']}  ({p['count']} trang)"
                info_lbl = tk.Label(
                    row,
                    text=info_text,
                    font=FONTS["small_bold"],
                    fg=COLORS["text_dark"],
                    bg="#F8FAFC",
                )
                info_lbl.pack(side="left", padx=(0, 10))

            # Tên file xuất
            tk.Label(
                row,
                text="Tên file:",
                font=FONTS["small"],
                fg=COLORS["text_muted"],
                bg="#F8FAFC",
            ).pack(side="left", padx=(0, 4))
            entry_fn = ModernEntry(row, textvariable=p["filename_var"])
            entry_fn.pack(side="left", fill="x", expand=True)

    # ==========================================
    # CÁC THAO TÁC KHOẢNG TRANG TÙY CHỈNH
    # ==========================================
    def init_default_custom_ranges(self):
        base_name = ""
        if self.pdf_path.get():
            base_name, _ = os.path.splitext(os.path.basename(self.pdf_path.get()))

        total = max(1, self.total_pages)
        mid = (total + 1) // 2

        self.custom_ranges = [
            {
                "start_var": tk.StringVar(value="1"),
                "end_var": tk.StringVar(value=str(mid)),
                "name_var": tk.StringVar(
                    value=f"{base_name}_part1.pdf" if base_name else "phan_1.pdf"
                ),
            },
            {
                "start_var": tk.StringVar(value=str(mid + 1)),
                "end_var": tk.StringVar(value=str(total)),
                "name_var": tk.StringVar(
                    value=f"{base_name}_part2.pdf" if base_name else "phan_2.pdf"
                ),
            },
        ]

    def add_custom_range_row(self):
        total = max(1, self.total_pages)
        base_name = ""
        if self.pdf_path.get():
            base_name, _ = os.path.splitext(os.path.basename(self.pdf_path.get()))

        next_start = 1
        if self.custom_ranges:
            try:
                last_end = int(self.custom_ranges[-1]["end_var"].get())
                next_start = min(total, last_end + 1)
            except ValueError:
                next_start = 1

        next_num = len(self.custom_ranges) + 1
        self.custom_ranges.append(
            {
                "start_var": tk.StringVar(value=str(next_start)),
                "end_var": tk.StringVar(value=str(total)),
                "name_var": tk.StringVar(
                    value=f"{base_name}_part{next_num}.pdf"
                    if base_name
                    else f"phan_{next_num}.pdf"
                ),
            }
        )
        self.refresh_split_calculation()

    def remove_custom_range_row(self, index):
        if len(self.custom_ranges) > 1:
            self.custom_ranges.pop(index)
            self.refresh_split_calculation()

    def auto_fill_ranges_from_total(self):
        self.init_default_custom_ranges()
        self.refresh_split_calculation()

    # ==========================================
    # LOGIC NẠP FILE & XỬ LÝ SỰ KIỆN
    # ==========================================
    def add_log(self, message, prefix="ℹ️"):
        now_str = datetime.now().strftime("%H:%M:%S")
        log_line = f"[{now_str}] {prefix} {message}\n"
        self.log_text.insert("end", log_line)
        self.log_text.see("end")

    def prompt_create_folder_manually(self):
        current_dir = self.output_dir.get().strip() or os.getcwd()
        folder_name = simpledialog.askstring(
            "Tạo Thư Mục Mới",
            f"Nhập tên thư mục mới muốn tạo trong:\n{current_dir}",
            parent=self,
        )
        if folder_name and folder_name.strip():
            new_path = os.path.join(current_dir, folder_name.strip())
            try:
                os.makedirs(new_path, exist_ok=True)
                self.output_dir.set(new_path)
                self.add_log(f"Đã tạo thư mục mới: {new_path}", prefix="📁")
                messagebox.showinfo(
                    "Thành Công", f"Đã tạo thư mục mới thành công:\n{new_path}"
                )
            except Exception as e:
                self.add_log(f"Lỗi tạo thư mục: {str(e)}", prefix="❌")
                messagebox.showerror(
                    "Lỗi Tạo Thư Mục", f"Không thể tạo thư mục:\n{str(e)}"
                )

    def browse_pdf_file(self):
        file_selected = filedialog.askopenfilename(
            title="Chọn sách PDF cần tách",
            filetypes=[("PDF files", "*.pdf"), ("All files", "*.*")],
        )
        if file_selected:
            self.pdf_path.set(file_selected)
            try:
                reader = PdfReader(file_selected)
                self.total_pages = len(reader.pages)
                file_size_mb = os.path.getsize(file_selected) / (1024 * 1024)
                file_name = os.path.basename(file_selected)

                base_dir = os.path.dirname(file_selected)
                if not self.output_dir.get():
                    self.output_dir.set(base_dir)

                base_name, _ = os.path.splitext(file_name)
                self.subfolder_name.set(f"{base_name}_DaTach")

                # Cập nhật badges
                self.lbl_book_name.config(
                    text=f"📄 {file_name}", fg=COLORS["text_dark"]
                )
                self.lbl_book_pages.config(text=f"📑 {self.total_pages} trang")
                self.lbl_book_size.config(text=f"💾 {file_size_mb:.2f} MB")

                self.custom_ranges = []
                self.refresh_split_calculation()
                self.lbl_status.config(
                    text="● Đã nạp sách thành công", fg=COLORS["success"]
                )
                self.add_log(
                    f"Đã nạp file: {file_name} ({self.total_pages} trang, {file_size_mb:.2f} MB)",
                    prefix="📖",
                )
            except Exception as e:
                self.add_log(f"Lỗi khi đọc file PDF: {str(e)}", prefix="❌")
                messagebox.showerror(
                    "Lỗi đọc file", f"Không thể đọc thông tin file PDF:\n{str(e)}"
                )

    def browse_output_dir(self):
        dir_selected = filedialog.askdirectory(title="Chọn thư mục lưu file xuất")
        if dir_selected:
            self.output_dir.set(dir_selected)
            self.add_log(f"Đã chọn thư mục lưu: {dir_selected}", prefix="📂")

    def set_progress(self, percentage, step_text=""):
        percentage = max(0, min(100, percentage))
        self.lbl_percentage.config(text=f"{percentage}%")
        if step_text:
            self.lbl_process_step.config(text=step_text)

        self.progress_canvas.delete("all")
        w = self.progress_canvas.winfo_width()
        h = self.progress_canvas.winfo_height()
        fill_w = int(w * (percentage / 100))
        if fill_w > 0:
            self.progress_canvas.create_rectangle(
                0, 0, fill_w, h, fill=COLORS["primary"], outline=""
            )

    # ==========================================
    # XUẤT SÁCH ĐA LUỒNG (EXPORT PROCESSING)
    # ==========================================
    def start_export_thread(self):
        if self.is_processing:
            return

        pdf_file = self.pdf_path.get().strip()
        base_out_dir = self.output_dir.get().strip()

        if not pdf_file or not os.path.exists(pdf_file):
            messagebox.showwarning(
                "Thiếu dữ liệu", "Vui lòng chọn file sách PDF nguồn!"
            )
            return

        if not base_out_dir:
            messagebox.showwarning(
                "Thiếu dữ liệu", "Vui lòng chọn thư mục lưu kết quả!"
            )
            return

        if not self.calculated_parts:
            messagebox.showwarning(
                "Thiếu dữ liệu", "Chưa có thông tin phân chia sách hợp lệ!"
            )
            return

        # Xác định thư mục đích
        target_dir = base_out_dir
        if self.create_subfolder.get():
            sub_name = self.subfolder_name.get().strip()
            if sub_name:
                target_dir = os.path.join(base_out_dir, sub_name)

        if not os.path.exists(target_dir):
            if self.ask_before_create_dir.get():
                confirm_msg = (
                    f"📁 Thư mục lưu kết quả chưa tồn tại:\n\n"
                    f'👉 "{target_dir}"\n\n'
                    f"Bạn có muốn tạo mới thư mục này không?"
                )
                if not messagebox.askyesno("Xác Nhận Tạo Thư Mục", confirm_msg):
                    self.add_log("Người dùng huỷ bỏ thao tác xuất sách.", prefix="⚠️")
                    self.lbl_status.config(
                        text="● Đã huỷ thao tác xuất sách", fg=COLORS["text_muted"]
                    )
                    return
            try:
                os.makedirs(target_dir, exist_ok=True)
                self.add_log(f"Đã tạo thư mục đích: {target_dir}", prefix="📁")
            except Exception as e:
                self.add_log(f"Lỗi tạo thư mục: {str(e)}", prefix="❌")
                messagebox.showerror(
                    "Lỗi tạo thư mục", f"Không thể tạo thư mục:\n{str(e)}"
                )
                return

        # Chuẩn bị danh sách file xuất
        export_tasks = []
        for p in self.calculated_parts:
            fname = p["filename_var"].get().strip()
            if not fname.lower().endswith(".pdf"):
                fname += ".pdf"
            out_file_path = os.path.join(target_dir, fname)
            export_tasks.append(
                {
                    "part_num": p["part_num"],
                    "start": p["start"],
                    "end": p["end"],
                    "count": p["count"],
                    "path": out_file_path,
                    "filename": fname,
                }
            )

        self.is_processing = True
        self.btn_export.set_state("disabled")
        self.set_progress(0, "Khởi động...")
        mode_desc = (
            f"chia {len(export_tasks)} phần"
            if self.split_mode.get() == "by_parts"
            else f"cắt {len(export_tasks)} khoảng trang"
        )
        self.lbl_status.config(text=f"⏳ Đang {mode_desc}...", fg=COLORS["primary"])
        self.add_log(f"Bắt đầu quy trình xuất sách ({mode_desc})...", prefix="🚀")

        thread = threading.Thread(
            target=self._process_multi_export, args=(pdf_file, export_tasks, target_dir)
        )
        thread.daemon = True
        thread.start()

    def _process_multi_export(self, pdf_file, export_tasks, target_dir):
        try:
            start_time = time.time()
            reader = PdfReader(pdf_file)
            total_pages = len(reader.pages)
            total_parts = len(export_tasks)

            total_pages_to_write = sum(t["count"] for t in export_tasks)
            pages_written = 0

            for part_idx, task in enumerate(export_tasks):
                p_num = task["part_num"]
                start_p = task["start"]
                end_p = task["end"]
                out_path = task["path"]
                fname = task["filename"]

                self.after(
                    0,
                    self.add_log,
                    f"Đang trích xuất Phần {p_num}/{total_parts}: trang {start_p} -> {end_p} ({task['count']} trang)...",
                    "⏳",
                )

                writer = PdfWriter()
                for page_i in range(start_p - 1, end_p):
                    writer.add_page(reader.pages[page_i])
                    pages_written += 1

                    pct = int(pages_written / total_pages_to_write * 95)
                    step_msg = f"Ghi Phần {p_num}: trang {page_i + 1}/{end_p}"
                    self.after(0, self.set_progress, pct, step_msg)

                with open(out_path, "wb") as f:
                    writer.write(f)

                self.after(0, self.add_log, f"Đã ghi xong Phần {p_num}: {fname}", "✅")

            elapsed = time.time() - start_time
            self.after(0, self.set_progress, 100, "Hoàn tất 100%")
            self.after(
                0,
                self.add_log,
                f"Đã xuất thành công {total_parts} file trong {elapsed:.2f} giây!",
                "🎉",
            )

            self.after(
                0, self._on_multi_export_success, export_tasks, target_dir, total_pages
            )
        except Exception as e:
            self.after(0, self._on_export_error, str(e))

    def _on_multi_export_success(self, export_tasks, target_dir, total_pages):
        self.is_processing = False
        self.btn_export.set_state("normal")
        self.lbl_status.config(
            text=f"✅ Đã xuất {len(export_tasks)} phần thành công!",
            fg=COLORS["success"],
        )

        file_list_str = "\n".join(
            [
                f"🔹 Phần {t['part_num']}: {t['filename']} (Trang {t['start']} -> {t['end']}, {t['count']} trang)"
                for t in export_tasks
            ]
        )

        msg = (
            f"🎉 Xuất sách hoàn tất thành {len(export_tasks)} file:\n\n"
            f"{file_list_str}\n\n"
            f"📁 Lưu tại: {target_dir}\n\n"
            f"Bạn có muốn mở ngay thư mục chứa các file vừa xuất?"
        )
        if messagebox.askyesno("Xuất Sách Thành Công", msg):
            try:
                if sys.platform == "darwin":
                    subprocess.Popen(["open", target_dir])
                elif sys.platform == "win32":
                    os.startfile(target_dir)
                else:
                    subprocess.Popen(["xdg-open", target_dir])
            except Exception:
                pass

    def _on_export_error(self, error_msg):
        self.is_processing = False
        self.btn_export.set_state("normal")
        self.set_progress(0, "Lỗi xảy ra")
        self.lbl_status.config(text="❌ Lỗi khi xuất sách", fg=COLORS["danger"])
        self.add_log(f"Lỗi: {error_msg}", prefix="❌")
        messagebox.showerror("Lỗi Xuất Sách", f"Không thể xuất file PDF:\n{error_msg}")


def main():
    app = PdfSplitterApp()
    app.mainloop()


if __name__ == "__main__":
    main()
