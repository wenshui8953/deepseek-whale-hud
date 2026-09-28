param(
    [int]$TestSeconds = 0,
    [string]$SelfShotFile = ''
)

# ============================================================
#  鲸鱼娘 · 桌面余额挂件 (DSH 风格)
#  - 纯立绘透明悬浮（分层窗口，完美 alpha）
#  - 轻轻上下浮动 + 点击弹气泡 + 拖动 + 60s 刷新
#  立绘素材来源于 dsh-whale-widget (MeteorNOX, MIT)
# ============================================================

$ErrorActionPreference = 'Continue'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles() | Out-Null
[System.Windows.Forms.Application]::SetUnhandledExceptionMode([System.Windows.Forms.UnhandledExceptionMode]::CatchException)

# ---- 分层窗口 C# 类（完美透明背景） ----
Add-Type -TypeDefinition @'
using System;
using System.Drawing;
using System.Runtime.InteropServices;
using System.Windows.Forms;

public class LayeredForm : Form
{
    private Bitmap _bitmap;

    public LayeredForm()
    {
        FormBorderStyle = FormBorderStyle.None;
        ShowInTaskbar = false;
        StartPosition = FormStartPosition.Manual;
        TopMost = true;
    }

    public static void EnableDPIAware()
    {
        try { SetProcessDPIAware(); } catch { }
    }

    protected override CreateParams CreateParams
    {
        get
        {
            CreateParams cp = base.CreateParams;
            cp.ExStyle |= 0x80000;
            return cp;
        }
    }

    public void MoveTo(int x, int y)
    {
        this.Left = x;
        this.Top = y;
        ApplyBitmap(x, y);
    }

    public void SetBitmap(Bitmap bitmap)
    {
        _bitmap = bitmap;
        ApplyBitmap(this.Left, this.Top);
    }

    private void ApplyBitmap(int x, int y)
    {
        if (_bitmap == null) return;
        IntPtr screenDc = GetDC(IntPtr.Zero);
        IntPtr memDc = CreateCompatibleDC(screenDc);
        IntPtr hBitmap = IntPtr.Zero;
        IntPtr oldBitmap = IntPtr.Zero;
        try
        {
            hBitmap = _bitmap.GetHbitmap(Color.FromArgb(0));
            oldBitmap = SelectObject(memDc, hBitmap);
            Size size = new Size(_bitmap.Width, _bitmap.Height);
            Point pointSource = new Point(0, 0);
            Point topPos = new Point(x, y);
            BLENDFUNCTION blend = new BLENDFUNCTION();
            blend.BlendOp = 0;
            blend.BlendFlags = 0;
            blend.SourceConstantAlpha = 255;
            blend.AlphaFormat = 1;
            UpdateLayeredWindow(this.Handle, screenDc, ref topPos, ref size, memDc, ref pointSource, 0, ref blend, 2);
        }
        finally
        {
            ReleaseDC(IntPtr.Zero, screenDc);
            if (hBitmap != IntPtr.Zero)
            {
                SelectObject(memDc, oldBitmap);
                DeleteObject(hBitmap);
            }
            DeleteDC(memDc);
        }
    }

    [StructLayout(LayoutKind.Sequential, Pack = 1)]
    private struct BLENDFUNCTION
    {
        public byte BlendOp;
        public byte BlendFlags;
        public byte SourceConstantAlpha;
        public byte AlphaFormat;
    }

    [DllImport("user32.dll")] private static extern bool SetProcessDPIAware();
    [DllImport("user32.dll")] private static extern IntPtr GetDC(IntPtr hWnd);
    [DllImport("user32.dll")] private static extern int ReleaseDC(IntPtr hWnd, IntPtr hDC);
    [DllImport("gdi32.dll")] private static extern IntPtr CreateCompatibleDC(IntPtr hDC);
    [DllImport("gdi32.dll")] private static extern bool DeleteDC(IntPtr hDC);
    [DllImport("gdi32.dll")] private static extern IntPtr SelectObject(IntPtr hDC, IntPtr hObject);
    [DllImport("gdi32.dll")] private static extern bool DeleteObject(IntPtr hObject);
    [DllImport("user32.dll")] private static extern bool UpdateLayeredWindow(IntPtr hwnd, IntPtr hdcDst, ref Point pptDst, ref Size psize, IntPtr hdcSrc, ref Point pptSrc, int crKey, ref BLENDFUNCTION pblend, int dwFlags);
}
'@ -ReferencedAssemblies System.Drawing, System.Windows.Forms | Out-Null

[LayeredForm]::EnableDPIAware()

$root   = Split-Path -Parent $MyInvocation.MyCommand.Path
$keyFile = Join-Path $root '.key'
if (-not (Test-Path $keyFile)) { exit 1 }
$key    = (Get-Content $keyFile -Raw).Trim()

# 素材目录：优先使用脚本同目录的 assets/，否则回退到 DSH 插件包路径
$assetsLocal = Join-Path $root 'assets'
if (Test-Path (Join-Path $assetsLocal 'DSniang1.png')) {
    $assets = $assetsLocal
} else {
    $assets = Join-Path $env:USERPROFILE '.dsh\profiles\web\node_modules\dsh-whale-widget\assets'
}

# ---- 单实例互斥 ----
$mutex = New-Object System.Threading.Mutex($false, 'Local\WhaleHUD_WorkBuddy')
if (-not $mutex.WaitOne(0)) { exit 0 }

# ---- 布局常量（物理像素） ----
$script:VW = 260
$script:VH = 296
$script:AVS = 190     # 立绘尺寸
$script:AVX = 35      # 立绘 x
$script:AVY = 52      # 立绘 y

# ---- 状态 ----
$script:phase      = 0.0
$script:balance    = '--'
$script:prevBalance = $null
$script:sub        = '正在查询...'
$script:amountColor = [System.Drawing.Color]::White
$script:dotColor    = [System.Drawing.Color]::FromArgb(126, 147, 168)
$script:avatarPath  = Join-Path $assets 'DSniang1.png'
$script:avatar      = $null
$script:bubbleUntil = [DateTime]::MinValue
$script:bubbleLine1 = ''
$script:bubbleLine2 = ''
$script:soundOn     = $true
$hbFile  = Join-Path $root 'hud-heartbeat.txt'
$posFile = Join-Path $root 'hud-pos2.txt'

$avatarChoices = @(
    @{ Name = 'DS娘 · 标准'; File = 'DSniang1.png' },
    @{ Name = 'DS娘 · 高清'; File = 'DSniang02.png' },
    @{ Name = 'DSH · 横版';  File = 'DSH2.png' }
)

function LoadAvatar {
    try {
        if ($script:avatar) { $script:avatar.Dispose(); $script:avatar = $null }
        if (Test-Path $script:avatarPath) {
            $script:avatar = [System.Drawing.Image]::FromFile($script:avatarPath)
        }
    } catch { $script:avatar = $null }
}

function PlayTick {
    if (-not $script:soundOn) { return }
    try {
        $wav = Join-Path $assets 'minecraft-exp-orb.wav'
        if (Test-Path $wav) {
            $p = New-Object System.Media.SoundPlayer $wav
            $p.Play()
        }
    } catch {}
}

function RefreshBalance {
    try {
        $r = Invoke-RestMethod -Uri 'https://api.deepseek.com/user/balance' `
            -Headers @{ Authorization = "Bearer $key"; Accept = 'application/json' } `
            -TimeoutSec 8
        $cny = 0.0
        foreach ($b in $r.balance_infos) {
            if ($b.currency -eq 'CNY') { $cny += [double]$b.total_balance }
            elseif ($b.currency -eq 'USD') { $cny += [double]$b.total_balance * 7.2 }
        }
        $newText = ('¥{0:N2}' -f $cny)
        $delta = ''
        if ($script:prevBalance -ne $null -and $script:prevBalance -ne $cny) {
            $d = $cny - [double]$script:prevBalance
            $delta = ('较上次 {0}{1:N2}' -f ($(if ($d -lt 0) { '-' } else { '+' })), [Math]::Abs($d))
        }
        $script:prevBalance = $cny
        $script:balance = $newText
        if ($cny -le 0) {
            $script:amountColor = [System.Drawing.Color]::FromArgb(255, 120, 120)
            $script:dotColor    = [System.Drawing.Color]::FromArgb(255, 107, 107)
            $script:sub         = 'API 不可用'
        } elseif ($cny -lt 5) {
            $script:amountColor = [System.Drawing.Color]::FromArgb(255, 186, 80)
            $script:dotColor    = [System.Drawing.Color]::FromArgb(255, 176, 32)
            $script:sub         = '余额偏低'
        } else {
            $script:amountColor = [System.Drawing.Color]::White
            $script:dotColor    = [System.Drawing.Color]::FromArgb(61, 214, 140)
            $script:sub         = '正常'
        }
        $script:bubbleLine1 = '余额 ' + $script:balance
        $script:bubbleLine2 = (Get-Date -Format 'HH:mm') + ' 更新' + $(if ($delta -ne '') { ' · ' + $delta } else { '' })
    } catch {
        $script:sub         = '查询失败'
        $script:dotColor    = [System.Drawing.Color]::FromArgb(255, 107, 107)
        $script:bubbleLine1 = '查询失败'
        $script:bubbleLine2 = '双击立绘可重试'
    }
    try {
        Set-Content -Path $hbFile -Value ((Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + ' balance=' + $script:balance + ' ' + $script:sub) -Encoding utf8
    } catch {}
    Render
}

LoadAvatar

# ---- 窗口 ----
$form = New-Object LayeredForm
$form.Size = New-Object System.Drawing.Size($script:VW, $script:VH)
$wa = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$startX = $wa.Right - $script:VW - 24
$startY = $wa.Bottom - $script:VH - 10
if (Test-Path $posFile) {
    try {
        $pp = (Get-Content $posFile -Raw).Trim() -split ','
        $startX = [int]$pp[0]; $startY = [int]$pp[1]
    } catch {}
}
$form.Left = $startX
$form.Top  = $startY

# ---- 画布与字体 ----
$script:canvas = New-Object System.Drawing.Bitmap($script:VW, $script:VH, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$script:cg = [System.Drawing.Graphics]::FromImage($script:canvas)

$fontAmount = New-Object System.Drawing.Font('Microsoft YaHei UI', 15, [System.Drawing.FontStyle]::Bold)
$fontSmall  = New-Object System.Drawing.Font('Microsoft YaHei UI', 8.5)
$fontBubble1 = New-Object System.Drawing.Font('Microsoft YaHei UI', 10.5, [System.Drawing.FontStyle]::Bold)
$fontBubble2 = New-Object System.Drawing.Font('Microsoft YaHei UI', 8.5)
$brushGray  = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(168, 190, 208))

function New-RoundedPath($x, $y, $w, $h, $r) {
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $p.AddArc($x, $y, $r, $r, 180, 90)
    $p.AddArc($x + $w - $r, $y, $r, $r, 270, 90)
    $p.AddArc($x + $w - $r, $y + $h - $r, $r, $r, 0, 90)
    $p.AddArc($x, $y + $h - $r, $r, $r, 90, 90)
    $p.CloseAllFigures()
    return $p
}

function Render {
    try {
        $g = $script:cg
        $g.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
        $g.Clear([System.Drawing.Color]::Transparent)

        $bob = [Math]::Sin($script:phase) * 3.5

        # 立绘
        if ($script:avatar) {
            $min  = [Math]::Min($script:avatar.Width, $script:avatar.Height)
            $srcX = ($script:avatar.Width  - $min) / 2
            $srcY = ($script:avatar.Height - $min) / 2
            $dest = New-Object System.Drawing.RectangleF([float]$script:AVX, [float]($script:AVY + $bob), [float]$script:AVS, [float]$script:AVS)
            $src  = New-Object System.Drawing.RectangleF([float]$srcX, [float]$srcY, [float]$min, [float]$min)
            $g.DrawImage($script:avatar, $dest, $src, [System.Drawing.GraphicsUnit]::Pixel)
        }

        # 余额胶囊
        $capW = 208; $capH = 42
        $capX = ($script:VW - $capW) / 2
        $capY = $script:VH - $capH - 8
        $path = New-RoundedPath $capX $capY $capW $capH 21
        $capBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(216, 16, 24, 36))
        $g.FillPath($capBrush, $path)
        $capBrush.Dispose()
        $penEdge = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(60, 90, 130)), 1.0
        $g.DrawPath($penEdge, $path)
        $penEdge.Dispose()
        $path.Dispose()

        $dot = New-Object System.Drawing.SolidBrush ($script:dotColor)
        $g.FillEllipse($dot, [float]($capX + 16), [float]($capY + 16), 10, 10)
        $dot.Dispose()

        $ab = New-Object System.Drawing.SolidBrush ($script:amountColor)
        $g.DrawString($script:balance, $fontAmount, $ab, [float]($capX + 36), [float]($capY + 7))
        $ab.Dispose()
        $g.DrawString($script:sub, $fontSmall, $brushGray, [float]($capX + 152), [float]($capY + 14))

        # 气泡
        if ((Get-Date) -lt $script:bubbleUntil) {
            $bW = 224; $bH = 60
            $bX = ($script:VW - $bW) / 2
            $bY = 2
            $bp = New-RoundedPath $bX $bY $bW $bH 14
            $bb = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(232, 22, 32, 48))
            $g.FillPath($bb, $bp)
            $bb.Dispose()
            $bpen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(80, 120, 170)), 1.0
            $g.DrawPath($bpen, $bp)
            $bpen.Dispose()
            $bp.Dispose()
            $wt = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::White)
            $g.DrawString($script:bubbleLine1, $fontBubble1, $wt, [float]($bX + 16), [float]($bY + 8))
            $wt.Dispose()
            $g.DrawString($script:bubbleLine2, $fontBubble2, $brushGray, [float]($bX + 16), [float]($bY + 34))
        }

        $form.SetBitmap($script:canvas)
    } catch {
        try {
            Set-Content -Path (Join-Path $root 'hud-paint-error.txt') `
                -Value ((Get-Date -Format 'HH:mm:ss') + ' : ' + $_.Exception.Message + ' @ ' + $_.InvocationInfo.PositionMessage) `
                -Encoding utf8
        } catch {}
    }
}

# ---- 交互 ----
$script:dragStart = $null
$script:dragging  = $false
$form.add_MouseDown({
    if ($_.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
        $script:dragStart = [System.Windows.Forms.Cursor]::Position
        $script:formStart = @($form.Left, $form.Top)
        $script:dragging  = $false
    }
})
$form.add_MouseMove({
    if ($script:dragStart) {
        $p  = [System.Windows.Forms.Cursor]::Position
        $dx = $p.X - $script:dragStart.X
        $dy = $p.Y - $script:dragStart.Y
        if (([Math]::Abs($dx) + [Math]::Abs($dy)) -gt 4) { $script:dragging = $true }
        if ($script:dragging) {
            $form.MoveTo($script:formStart[0] + $dx, $script:formStart[1] + $dy)
        }
    }
})
$form.add_MouseUp({
    if ($script:dragStart) {
        $script:dragStart = $null
        if ($script:dragging) {
            try { Set-Content -Path $posFile -Value ("{0},{1}" -f $form.Left, $form.Top) -Encoding ascii } catch {}
            $script:dragging = $false
        } else {
            # 单击 → 弹气泡
            $script:bubbleUntil = (Get-Date).AddSeconds(6)
            PlayTick
            Render
        }
    }
})
$form.add_DoubleClick({ RefreshBalance })

# ---- 右键菜单 ----
$menu = New-Object System.Windows.Forms.ContextMenuStrip
$miRefresh = $menu.Items.Add('立即刷新')
$miRefresh.add_Click({ RefreshBalance })
$miAvatar = New-Object System.Windows.Forms.ToolStripMenuItem('换个形象')
foreach ($c in $avatarChoices) {
    $item = $miAvatar.DropDownItems.Add($c.Name)
    $file = $c.File
    $item.add_Click({
        $script:avatarPath = Join-Path $assets $file
        LoadAvatar
        Render
    }.GetNewClosure())
}
$menu.Items.Add($miAvatar) | Out-Null
$miSound = $menu.Items.Add('音效：开')
$miSound.add_Click({
    $script:soundOn = -not $script:soundOn
    $miSound.Text = $(if ($script:soundOn) { '音效：开' } else { '音效：关' })
    PlayTick
})
$miDsh = $menu.Items.Add('打开 DSH 鲸鱼娘')
$miDsh.add_Click({ Start-Process 'http://127.0.0.1:3080' })
$miTop = $menu.Items.Add('打开充值页')
$miTop.add_Click({ Start-Process 'https://platform.deepseek.com/top_up' })
$menu.Items.Add('-') | Out-Null
$miExit = $menu.Items.Add('退出')
$miExit.add_Click({ $form.Close() })
$form.ContextMenuStrip = $menu

# ---- 定时器 ----
$at = New-Object System.Windows.Forms.Timer   # 浮动动画
$at.Interval = 100
$at.add_Tick({
    $script:phase += 0.16
    if ($script:phase -gt 6.28) { $script:phase -= 6.28 }
    Render
})
$rt = New-Object System.Windows.Forms.Timer   # 余额刷新
$rt.Interval = 60000
$rt.add_Tick({ RefreshBalance })

$form.add_Shown({
    RefreshBalance
    $at.Start()
    $rt.Start()
    if ($SelfShotFile -ne '') {
        $script:st = New-Object System.Windows.Forms.Timer
        $script:st.Interval = 1500
        $script:st.add_Tick({
            $script:st.Stop()
            try {
                $loc = @($form.Left, $form.Top)
                $sw = $script:VW + 40; $sh = $script:VH + 40
                $bmp = New-Object System.Drawing.Bitmap($sw, $sh)
                $g = [System.Drawing.Graphics]::FromImage($bmp)
                $g.CopyFromScreen(($loc[0] - 20), ($loc[1] - 20), 0, 0, (New-Object System.Drawing.Size($sw, $sh)))
                $g.Dispose()
                $bmp.Save($SelfShotFile, [System.Drawing.Imaging.ImageFormat]::Png)
                $bmp.Dispose()
            } catch {}
            $form.Close()
        })
        $script:st.Start()
    }
})

if ($TestSeconds -gt 0) {
    $script:t2 = New-Object System.Windows.Forms.Timer
    $script:t2.Interval = $TestSeconds * 1000
    $script:t2.add_Tick({ $script:t2.Stop(); $form.Close() })
    $script:t2.Start()
}

Render
$form.Show()
[System.Windows.Forms.Application]::Run($form)
