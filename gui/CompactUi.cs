using System;
using System.Drawing;
using System.Runtime.InteropServices;
using System.Windows.Forms;

namespace TekSoftwareUi
{
    internal static class CompactTheme
    {
        public static readonly Color Blue = Color.FromArgb(0, 110, 235);
        public static readonly Color Ink = Color.FromArgb(24, 30, 40);
        public static readonly Color Muted = Color.FromArgb(93, 102, 116);
        public static readonly Color Border = Color.FromArgb(216, 222, 231);
        public static readonly Color Surface = Color.FromArgb(245, 247, 250);
        public static readonly Color Selection = Color.FromArgb(235, 244, 255);

        public static void Apply(Form form)
        {
            form.BackColor = Color.White;
            form.Font = new Font("Segoe UI", 9.5F);
            StyleChildren(form, form.AcceptButton as Button);
        }

        private static void StyleChildren(Control parent, Button primary)
        {
            foreach (Control control in parent.Controls)
            {
                Button button = control as Button;
                if (button != null)
                {
                    bool filled = button == primary || button.ForeColor.ToArgb() == Color.White.ToArgb();
                    button.FlatStyle = FlatStyle.Flat;
                    button.FlatAppearance.BorderColor = filled ? Blue : Border;
                    button.FlatAppearance.BorderSize = 1;
                    button.BackColor = filled ? Blue : Color.White;
                    button.ForeColor = filled ? Color.White : Ink;
                    button.Font = new Font("Segoe UI", 9.5F);
                    button.UseVisualStyleBackColor = false;
                    button.Cursor = Cursors.Hand;
                }
                else if (control is Label)
                {
                    Label label = (Label)control;
                    bool title = label.Font.Size >= 14F;
                    label.Font = new Font("Segoe UI", title ? 16F : 9.5F, title ? FontStyle.Bold : label.Font.Style);
                    label.ForeColor = title ? Ink : Muted;
                    if (label.BackColor != Color.Transparent && label.BackColor != Color.White)
                        label.BackColor = Surface;
                }
                else if (control is TextBox)
                {
                    TextBox textBox = (TextBox)control;
                    if (!textBox.Multiline) textBox.Font = new Font("Segoe UI", 10F);
                    textBox.ForeColor = Ink;
                    textBox.BackColor = textBox.ReadOnly ? Surface : Color.White;
                    textBox.BorderStyle = BorderStyle.FixedSingle;
                }
                else if (control is ListBox)
                {
                    ListBox list = (ListBox)control;
                    list.BackColor = Color.White;
                    list.ForeColor = Ink;
                    list.Font = new Font("Segoe UI", 9.5F);
                    list.BorderStyle = BorderStyle.FixedSingle;
                    if (list.DrawMode == DrawMode.Normal) list.ItemHeight = 25;
                    list.IntegralHeight = false;
                }
                else if (control is CheckBox || control is RadioButton || control is ComboBox)
                {
                    control.ForeColor = Ink;
                    control.Font = new Font("Segoe UI", 9.5F);
                }
                else if (control is Panel && !(control is FlowLayoutPanel))
                {
                    if (control.Width <= 6 && control.Height > 20) control.Visible = false;
                    else if (control.BackColor != Color.White && control.BackColor != Color.Transparent)
                        control.BackColor = Surface;
                }
                else if (control is GroupBox)
                {
                    control.ForeColor = Ink;
                    control.Font = new Font("Segoe UI", 9.5F);
                }
                StyleChildren(control, primary);
            }
        }

        public static Panel Header(int width, string titleText, string subtitleText)
        {
            Panel panel = new Panel();
            panel.SetBounds(0, 0, width, 72);
            panel.BackColor = Color.White;
            panel.Anchor = AnchorStyles.Left | AnchorStyles.Right | AnchorStyles.Top;
            Label title = new Label();
            title.Text = titleText;
            title.SetBounds(24, 14, width - 48, 28);
            title.Font = new Font("Segoe UI", 16F, FontStyle.Bold);
            title.ForeColor = Ink;
            panel.Controls.Add(title);
            Label subtitle = new Label();
            subtitle.Text = subtitleText;
            subtitle.SetBounds(24, 46, width - 48, 22);
            subtitle.Font = new Font("Segoe UI", 9F);
            subtitle.ForeColor = Muted;
            subtitle.AutoEllipsis = true;
            panel.Controls.Add(subtitle);
            return panel;
        }
    }

    internal class CompactDialog : Form
    {
        protected CompactDialog()
        {
            AutoScaleDimensions = new SizeF(96F, 96F);
            AutoScaleMode = AutoScaleMode.Dpi;
            ShowInTaskbar = false;
            StartPosition = FormStartPosition.CenterParent;
        }

        protected override void OnLoad(EventArgs e)
        {
            CompactTheme.Apply(this);
            base.OnLoad(e);
        }
    }

    internal sealed class SearchBox : TextBox
    {
        public string CueText = "Buscar";
        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        private static extern IntPtr SendMessage(IntPtr handle, int message, IntPtr wparam, string lparam);
        protected override void OnHandleCreated(EventArgs e)
        {
            base.OnHandleCreated(e);
            SendMessage(Handle, 0x1501, IntPtr.Zero, CueText);
        }
    }

    internal sealed class CompactTabs : TabControl
    {
        public CompactTabs()
        {
            DrawMode = TabDrawMode.OwnerDrawFixed;
            SizeMode = TabSizeMode.Fixed;
            ItemSize = new Size(96, 30);
            Font = new Font("Segoe UI", 9.5F);
            DrawItem += DrawTab;
        }

        private void DrawTab(object sender, DrawItemEventArgs e)
        {
            bool selected = e.Index == SelectedIndex;
            using (Brush fill = new SolidBrush(Color.White)) e.Graphics.FillRectangle(fill, e.Bounds);
            TextRenderer.DrawText(e.Graphics, TabPages[e.Index].Text, Font, e.Bounds,
                selected ? CompactTheme.Blue : CompactTheme.Ink,
                TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter | TextFormatFlags.EndEllipsis);
            if (selected)
                using (Pen pen = new Pen(CompactTheme.Blue, 3F))
                    e.Graphics.DrawLine(pen, e.Bounds.Left + 6, e.Bounds.Bottom - 2, e.Bounds.Right - 6, e.Bounds.Bottom - 2);
            if ((e.State & DrawItemState.Focus) != 0) ControlPaint.DrawFocusRectangle(e.Graphics, e.Bounds);
        }
    }

    internal sealed class ExecutionLogDialog : CompactDialog
    {
        private readonly TextBox output = new TextBox();
        private readonly System.Windows.Forms.Timer refresh = new System.Windows.Forms.Timer();
        private readonly Func<string> source;

        public ExecutionLogDialog(Func<string> sourceText)
        {
            source = sourceText;
            Text = "TEK Toolkit · Log de execução";
            ClientSize = new Size(700, 420);
            MinimumSize = new Size(600, 340);
            Controls.Add(CompactTheme.Header(ClientSize.Width, "Log de execução", "Resultados e mensagens deste atendimento"));
            output.SetBounds(24, 86, 652, 274);
            output.Anchor = AnchorStyles.Top | AnchorStyles.Bottom | AnchorStyles.Left | AnchorStyles.Right;
            output.Multiline = true;
            output.ReadOnly = true;
            output.ScrollBars = ScrollBars.Both;
            output.WordWrap = false;
            output.Font = new Font("Consolas", 9F);
            output.Text = source();
            Controls.Add(output);
            Button copy = new Button();
            copy.Text = "Copiar log";
            copy.SetBounds(470, 376, 98, 32);
            copy.Anchor = AnchorStyles.Bottom | AnchorStyles.Right;
            copy.Click += delegate { if (output.TextLength > 0) Clipboard.SetText(output.Text); };
            Controls.Add(copy);
            Button close = new Button();
            close.Text = "Fechar";
            close.SetBounds(578, 376, 98, 32);
            close.Anchor = AnchorStyles.Bottom | AnchorStyles.Right;
            close.DialogResult = DialogResult.Cancel;
            Controls.Add(close);
            CancelButton = close;
            CompactTheme.Apply(this);
            refresh.Interval = 500;
            refresh.Tick += delegate
            {
                string text = source();
                if (output.Text != text && output.SelectionLength == 0)
                {
                    output.Text = text;
                    output.SelectionStart = output.TextLength;
                    output.ScrollToCaret();
                }
            };
            refresh.Start();
            FormClosed += delegate { refresh.Stop(); refresh.Dispose(); };
        }
    }
}
