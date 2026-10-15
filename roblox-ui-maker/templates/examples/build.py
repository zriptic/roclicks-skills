#!/usr/bin/env python3
"""Example UI project: generates every HTML screen + index.html from shared components.

Usage (copy this folder into the game repo as ui/ first, see SKILL.md step 4; $SK = this skill's folder):
    cp <your downloaded stud texture> stud.png                            # from https://ui-resources.com (UI_RESOURCES.md)
    cp -r $SK/styles .                       # style presets (stud, glass)
    cp <the developer's reference> ref.png                                # the STYLE reference (required)
    python3 $SK/scripts/read_reference.py ref.png   # -> draft style.css
    python3 $SK/scripts/copy_icons.py icons.json --pack <your icon pack>   # your pack -> icons/
    python3 build.py                                                          # writes *.html
    python3 -m http.server 8870 --bind 127.0.0.1                              # then open /index.html

Style: UI_STYLE=stud (default) or UI_STYLE=glass picks the preset in styles/; style.css (from the
reference) is loaded after it. Any page also takes ?style=glass to preview another preset live.

Pages (1920x1080 stage, absolute px; ?raw = 1:1 for headless/export, ?check = flag overflowing text):
    style.html       the reference next to the tokens it produced (show this WITH the first screen)
    hud.html         HUD: cash + gems (BL), menu buttons (L), next-goal pill (T)        -> exported
    hud_phone.html   the same HUD laid out for a landscape phone (review only)
    shop.html        Shop panel: tabs, cards in every state (open/owned/locked/unaffordable) -> exported
    crate.html       crate opening: single reel, markers above/below, prize unobstructed  -> exported
    crate_odds.html  odds popup generated from the same table as the reel                -> exported
    templates.html   runtime templates sheet (toasts, confirm, reward popup)              -> templates
    states.html      every state of every element on one sheet (review only)
Icons: your one licensed icon pack only (icons/<slug>.png via icons.json). Textures: a ui-resources stud texture.

Export markers (read by scripts/dump.js): grp(name, html, anchor) = a top-level Roblox frame anchored
to a screen edge; sub(name, html, btn) = invisible named frame / button; name=... = data-n (the
instance name game code looks up); opens=... = attribute Opens (button toggles that screen);
hid=True = exported but Visible=false. Never put a double quote inside an inline style="...".
"""
import html
import os

HERE = os.path.dirname(os.path.abspath(__file__))
STYLE = os.environ.get('UI_STYLE', 'stud')
FONTS = ("<link rel='preconnect' href='https://fonts.googleapis.com'>"
         "<link href='https://fonts.googleapis.com/css2?family=Montserrat:wght@700;800;900"
         "&family=Source+Sans+3:wght@600;700&display=block' rel='stylesheet'>")


# ---------------------------------------------------------------- components
def dn(name):
    return f" data-n='{name}'" if name else ''


def T(text, size, cls='', fill='', style='', name=None, tag='span'):
    """Outlined live text. cls: xs/s/(default)/l/xl stroke sizes; fill: f-green etc."""
    t = html.escape(str(text), quote=True)
    return f"<{tag} class='ot {cls} {fill}' data-t='{t}'{dn(name)} style='font-size:{size}px;{style}'>{t}</{tag}>"


def I(icon, x, y, w, h=None, name=None, extra='', cls='ic'):
    h = h or w
    return f"<img class='{cls}' src='icons/{icon}.png'{dn(name)} style='left:{x}px;top:{y}px;width:{w}px;height:{h}px;{extra}'>"


def icn(icon, w, name=None, extra=''):
    return f"<img class='icn' src='icons/{icon}.png'{dn(name)} style='width:{w}px;height:{w}px;{extra}'>"


def grp(name, inner, anchor='C'):
    """Export group: invisible full-stage wrapper (coordinates unchanged) naming a top-level frame and
    the screen edge it sticks to: TL T TR L C R BL B BR, or FILL (full screen, e.g. Dim)."""
    return f"<div class='abs fill grp' data-g='{name}' data-a='{anchor}' style='pointer-events:none'>{inner}</div>"


def sub(name, inner, btn=False, opens=None, hid=False):
    """Invisible named frame whose box is the union of its children (btn=True -> TextButton)."""
    extra = (' data-btn=1' if btn else '') + (f" data-opens='{opens}'" if opens else '')
    return f"<div class='abs fill sub{' hid' if hid else ''}' data-n='{name}'{extra} style='pointer-events:none'>{inner}</div>"


def box(x, y, w, h, inner='', cls='', style='', name=None, hid=False):
    return f"<div class='abs {cls}{' hid' if hid else ''}'{dn(name)} style='left:{x}px;top:{y}px;width:{w}px;height:{h}px;{style}'>{inner}</div>"


def flex(inner, style=''):
    return f"<div class='abs fill' style='display:flex;align-items:center;justify-content:center;{style}'>{inner}</div>"


def plate(x, y, w, h, color, label='', cls='', name=None, opens=None, style='', lbl_style='', hid=False):
    extra = dn(name) + (f" data-opens='{opens}'" if opens else '')
    return (f"<div class='plate c-{color} {cls}{' hid' if hid else ''}'{extra} style='left:{x}px;top:{y}px;width:{w}px;height:{h}px;{style}'>"
            f"<div class='lbl' style='{lbl_style}'>{label}</div></div>")


def closeb():
    return f"<div class='plate c-red closeb' data-n='CloseButton'><div class='lbl'>{T('X', 50, 'l')}</div></div>"


def badge(x, y, text, name=None, hid=False):
    return f"<div class='badge{' hid' if hid else ''}'{dn(name)} style='left:{x}px;top:{y}px'>{T(text, 28, 'xs', name='BadgeText')}</div>"


def bar(x, y, w, h, frac, grad='g-green', name='Bar'):
    """Bar frame + fill child F (runtime: UIKit.bar(bar, frac))."""
    return (f"<div class='bar' data-n='{name}' style='left:{x}px;top:{y}px;width:{w}px;height:{h}px'>"
            f"<i class='{grad}' data-n='F' style='width:{frac * 100:.1f}%'></i></div>")


def dim(a=.45):
    return grp('Dim', "<div class='abs fill' style='background:rgba(0,8,12,%s)'></div>" % a, 'FILL')


def panel(gname, title, color, icon, body, x, y, w, h):
    head = plate(-7, -7, w, 104, color, icn(icon, 84) + T(title, 58, 'l'), 'head', style=f'left:-7px;top:-7px;width:{w}px')
    return grp(gname, f"<div class='panel' data-n='Panel' style='left:{x}px;top:{y}px;width:{w}px;height:{h}px'>"
               f"{head}{closeb()}<div class='abs' style='left:0;top:97px;right:0;bottom:0'>{body}</div></div>", 'C')


def world():
    """Stand-in game world behind the UI (class .world is never exported). Swap for a real Studio
    capture of the game (<img class='world' src='bg.png'>) as soon as one exists."""
    return "<div class='world'></div>"


def roblox_topbar():
    return ("<div class='rbx' style='left:16px;top:12px;width:200px;height:64px;border-radius:18px'>Roblox top bar</div>")


# ---------------------------------------------------------------- HUD
def side_button(y, icon, label, name, opens=None, fill='', badge_txt=None, size=130, x=20):
    out = I(icon, x, y, size, name='Icon')
    out += f"<div class='abs' style='left:{x - 20}px;width:{size + 40}px;top:{y + size - 30}px;text-align:center'>{T(label, 32, 's', fill, name='Label')}</div>"
    if badge_txt:  # data-driven badge: exported hidden, runtime shows it only when something is actionable
        out += badge(x + size - 44, y - 2, badge_txt, name='Badge', hid=True)
    return sub(name, out, btn=True, opens=opens)


def goal_pill(x=660, y=22, w=600):
    tag = plate(8, 8, 128, 60, 'gold', icn('target', 34) + T('NEXT', 22, 'xs'), 'xsm', lbl_style='gap:6px')
    body = tag + I('speed', 150, 12, 52, name='GoalIcon')
    body += box(212, 6, 300, 44, T('Buy a Speed Coil', 28, 's', name='GoalText'), style='display:flex;align-items:center')
    body += box(w - 112, 6, 100, 44, T('0 / 1', 24, 'xs', 'f-yellow', name='GoalCount'), style='display:flex;align-items:center;justify-content:flex-end')
    body += bar(212, 54, w - 230, 12, 0.0, 'g-gold', 'GoalBar')
    return sub('GoalPill', f"<div class='glass' data-n='GoalBox' style='left:{x}px;top:{y}px;width:{w}px;height:76px'>{body}</div>", btn=True)


def currencies(big=False):
    k = 1.25 if big else 1
    out = I('gem', 30, int(1080 - 200 * k), int(64 * k), name='GemsIcon')
    out += box(int(30 + 72 * k), int(1080 - 196 * k), 360, int(60 * k), T('125', int(46 * k), '', 'f-purple', name='GemsText'), style='display:flex;align-items:center')
    out += I('cash', 22, int(1080 - 118 * k), int(90 * k), name='CashIcon')
    out += box(int(22 + 98 * k), int(1080 - 114 * k), 520, int(86 * k), T('$30,500', int(66 * k), 'l', 'f-green', name='CashText'), style='display:flex;align-items:center')
    return grp('Currencies', out, 'BL')


def hud_groups(big=False):
    k = 1.3 if big else 1
    s = int(130 * k)
    left = (side_button(300, 'shop', 'Shop', 'ShopButton', 'Shop', 'f-orange', '!', s) +
            side_button(300 + int(170 * k), 'crate', 'Crates', 'CratesButton', 'CrateOdds', size=s) +
            side_button(300 + int(340 * k), 'settings', 'Settings', 'SettingsButton', size=s))
    return currencies(big) + grp('LeftButtons', left, 'L') + grp('Goal', goal_pill(), 'T')


def s_hud():
    return world() + roblox_topbar() + hud_groups()


def s_hud_phone():
    """Landscape phone: the 1920x1080 canvas shows at ~0.36x, so tap targets >= 124 design px,
    text >= 26. Roblox's own thumbstick/jump are dashed placeholders to keep clear of."""
    out = world() + roblox_topbar() + hud_groups(big=True)
    out += "<div class='rbx' style='left:140px;top:640px;width:300px;height:300px'>Roblox thumbstick</div>"
    out += "<div class='rbx' style='left:1640px;top:760px;width:200px;height:200px'>Roblox jump</div>"
    out += "<div class='cap' style='left:760px;top:1020px'>phone layout: bigger menu buttons and currency, nothing under the thumbs</div>"
    return out


# ---------------------------------------------------------------- Shop
CARDS = [  # (state, icon, name, desc, price)
    ('open', 'speed', 'Speed Coil', '+25% walk speed', '250'),
    ('owned', 'magnet', 'Magnet', 'Collect from 2x further', ''),
    ('locked', 'luck', 'Lucky Charm', 'Reach Zone 2 to unlock', ''),
    ('poor', 'potion', 'Power Potion', 'x2 power for 10 min', '1.2K'),
]


def card(x, y, state, icon, name, desc, price, w=290, h=430):
    dimcls = ' dim' if state == 'locked' else ''
    inner = I(icon, (w - 170) // 2, 22, 170, name='Icon')
    if state == 'locked':
        inner += I('lock', w - 96, 14, 76, name='Lock')
    inner += f"<div class='abs' style='left:0;right:0;top:200px;text-align:center'>{T(name, 34, 's', name='ItemName')}</div>"
    col = 'f-red' if state == 'locked' else 'f-grey'
    inner += f"<div class='abs' style='left:10px;right:10px;top:248px;text-align:center'>{T(desc, 21, 'xs', col, name='Desc')}</div>"
    if state == 'open':
        btn = plate(18, h - 112, w - 46, 84, 'green', icn('coin', 46) + T(price, 40, 's', name='Price'), 'sm', name='BtnBuy')
    elif state == 'owned':
        btn = plate(18, h - 112, w - 46, 84, 'grey', icn('check', 44) + T('Owned', 36, 's'), 'sm off', name='BtnOwned')
    elif state == 'locked':
        btn = ''
    else:  # unaffordable: grey plate, price stays readable, the shortfall is named
        # grey plate WITHOUT the .off filter, so the price stays white and readable
        btn = (plate(18, h - 112, w - 46, 84, 'grey', icn('coin', 46) + T(price, 40, 's', name='Price'), 'sm', name='BtnBuy') +
               f"<div class='abs' style='left:0;right:0;top:{h - 150}px;text-align:center'>{T('Need 950 more', 20, 'xs', 'f-red', name='Short')}</div>")
    return box(x, y, w, h, inner + btn, f'tile{dimcls}', name=f'Card_{state}')


def s_shop():
    # each tab = a button holding an On and an Off look (Off hidden on the active tab, On hidden on the
    # others) so runtime switches tabs by toggling Visible; the labels stay live text.
    tabs = ''
    for i, (tab, col) in enumerate([('Items', 'blue'), ('Gems', 'purple'), ('Passes', 'green')]):
        x, active = 40 + i * 246, i == 0
        looks = (plate(x, 22, 230, 78, col, T(tab, 38, 's'), 'sm', name='On', hid=not active) +
                 plate(x, 22, 230, 78, col, T(tab, 38, 's'), 'sm off', name='Off', hid=active))
        tabs += sub('Tab' + tab, looks, btn=True)
    cards = ''.join(card(40 + i * 312, 128, *c) for i, c in enumerate(CARDS))
    body = tabs + box(24, 112, 1272, 470, '', 'inset') + cards
    return world() + hud_groups() + dim() + panel('Shop', 'Shop', 'yellow', 'shop', body, 300, 170, 1320, 700)


# ---------------------------------------------------------------- crate reel + odds (ONE table)
RARITY = {  # border colour, light, dark, text fill
    'common': ('#9aa2a9', '#eef1f4', '#9aa2a9', 'f-grey'),
    'rare': ('#2fa8ff', '#bfe6ff', '#2a7fd6', 'f-blue'),
    'epic': ('#b44dff', '#efc8ff', '#8a2fd8', 'f-purple'),
    'legendary': ('#ffc21c', '#fff3b8', '#f0a000', 'f-gold'),
}
REWARDS = [  # (icon, amount text, name, rarity, weight) -> odds % = weight / total (same table the server rolls)
    ('coin', '500', 'Coin Pouch', 'common', 55), ('gem_blue', '25', 'Gem Pile', 'rare', 30),
    ('potion', 'x2', 'Power Potion', 'epic', 12), ('trophy', '1', 'Golden Trophy', 'legendary', 3),
]


def reward_tile(x, y, icon, amount, rarity, s=190, name=None):
    bc, lt, dk, _ = RARITY[rarity]
    inner = I(icon, int(s * .18), int(s * .1), int(s * .64), name='Icon')
    inner += f"<div class='abs' style='left:0;right:0;bottom:{int(s * .05)}px;text-align:center'>{T(amount, int(s * .17), 's', name='Amount')}</div>"
    return box(x, y, s, s, inner, '', f'border:7px solid {bc};border-radius:20px;background:linear-gradient({lt},{dk});'
               'box-shadow:0 0 0 4px #070a0e', name=name or f'Tile_{rarity}')


def s_crate():
    out = world() + dim(.62)
    out += grp('CrateTitle', f"<div class='abs' style='left:0;right:0;top:150px;text-align:center'>{T('Golden Crate', 76, 'xl', 'f-gold', name='Title')}</div>", 'T')
    # strip: 1920 wide, tiles 190 + 16 gap, winner centred on x=960; the next tile is a cosmetic tease
    seq = ['common', 'rare', 'common', 'rare', 'epic', 'legendary', 'common', 'rare', 'common', 'epic']  # prize = index 4 (epic), tease = one rarity better
    icons = {'common': ('coin', '500'), 'rare': ('gem_blue', '25'), 'epic': ('potion', 'x2'), 'legendary': ('trophy', '1')}
    reel = box(0, 415, 1920, 250, '', '', 'background:rgba(0,0,0,.52);border-top:5px solid #070a0e;border-bottom:5px solid #070a0e', name='Strip')
    x0 = 960 - 95 - 4 * 206
    for i, r in enumerate(seq):
        ic, amt = icons[r]
        reel += reward_tile(x0 + i * 206, 445, ic, amt, r, name='Prize' if i == 4 else f'Tile{i + 1}')
    # edge fades and gold markers ABOVE and BELOW the prize: nothing is ever drawn over the prize
    reel += box(0, 420, 240, 240, '', '', 'background:linear-gradient(90deg,rgba(4,8,12,.95),rgba(4,8,12,0))', name='FadeL')
    reel += box(1680, 420, 240, 240, '', '', 'background:linear-gradient(90deg,rgba(4,8,12,0),rgba(4,8,12,.95))', name='FadeR')
    reel += ("<svg class='abs' style='left:0;top:0;width:1920px;height:1080px;overflow:visible'>"
             "<polygon data-n='MarkerTop' points='936,372 984,372 960,410' fill='#ffd23a' stroke='#070a0e' stroke-width='5'/>"
             "<polygon data-n='MarkerBottom' points='936,708 984,708 960,670' fill='#ffd23a' stroke='#070a0e' stroke-width='5'/></svg>")
    out += grp('Reel', reel, 'C')
    out += grp('SkipHint', f"<div class='abs' style='left:0;right:0;top:990px;text-align:center'>{T('Tap to skip', 30, 's', 'f-grey', name='Hint')}</div>", 'B')
    return out


def s_crate_odds():
    total = sum(r[4] for r in REWARDS)
    rows = ''
    for i, (ic, amt, nm, r, wgt) in enumerate(REWARDS):
        y = 24 + i * 92
        pct = f'{100 * wgt / total:.0f}%'
        row = reward_tile(14, 8, ic, amt, r, s=68, name='Tile')
        row += box(100, 6, 420, 40, T(nm, 30, 's', name='ItemName'), style='display:flex;align-items:center')
        row += box(100, 44, 420, 30, T(r.capitalize(), 22, 'xs', RARITY[r][3], name='Rarity'), style='display:flex;align-items:center')
        row += box(560, 10, 220, 64, T(pct, 40, '', RARITY[r][3], name='Pct'), style='display:flex;align-items:center;justify-content:flex-end')
        rows += box(30, y, 800, 84, row, '', 'background:rgba(255,255,255,.06);border-radius:16px', name=f'Row{i + 1}')
    seg, x = '', 0
    for ic, amt, nm, r, wgt in REWARDS:
        w = 800 * wgt / total
        seg += f"<i class='abs' style='left:{x:.1f}px;top:0;bottom:0;width:{w:.1f}px;background:{RARITY[r][0]}'></i>"
        x += w
    split = box(30, 404, 800, 26, seg, 'bar', name='Split')
    pity = f"<div class='abs' style='left:30px;right:30px;top:452px;text-align:center'>{T('Epic or better guaranteed at least once every 20 opens', 22, 'xs', 'f-yellow', name='Pity')}</div>"
    return world() + dim(.55) + panel('CrateOdds', 'Golden Crate odds', 'gold', 'crate_gold', rows + split + pity, 520, 200, 880, 610)


# ---------------------------------------------------------------- runtime templates sheet
def toast(x, y, kind, icon, text, gname):
    col = {'info': 'blue', 'good': 'green', 'error': 'red', 'cash': 'gold'}[kind]
    inner = f"<div class='glass' data-n='Body' style='left:40px;top:0;width:600px;height:84px;border-radius:0 20px 20px 0'></div>"
    inner += plate(0, -4, 92, 92, col, icn(icon, 60, name='Icon'), 'sm', name='KindPlate')
    inner += box(110, 0, 510, 76, T(text, 30, 's', name='Msg1'), style='display:flex;align-items:center')
    inner += bar(60, 70, 560, 10, 1.0, 'g-' + ('gold' if kind == 'cash' else {'info': 'blue', 'good': 'green', 'error': 'red'}[kind]), 'Time')
    return grp(gname, box(x, y, 640, 84, inner, name='Toast'), 'TL')


def confirm(x, y):
    inner = (f"<div class='abs' style='left:0;right:0;top:120px;text-align:center'>{T('Delete this pet?', 40, 's', name='Body1')}</div>"
             f"<div class='abs' style='left:0;right:0;top:176px;text-align:center'>{T('You get 120 coins back', 28, 'xs', 'f-grey', name='Body2')}</div>"
             + plate(60, 270, 300, 92, 'red', T('Delete', 42, 's', name='YesText'), name='BtnYes')
             + plate(400, 270, 300, 92, 'blue', T('Cancel', 42, 's', name='NoText'), name='BtnNo'))
    head = plate(-5, -5, 760, 96, 'red', T('Are you sure?', 50, 'l', name='Title'), 'head', style='left:-5px;top:-5px')
    return grp('Confirm', f"<div class='glass' data-n='Card' style='left:{x}px;top:{y}px;width:760px;height:400px'>{head}{closeb()}{inner}</div>", 'TL')


def reward_popup(x, y):
    inner = reward_tile(285, 120, 'gem_blue', '25', 'rare', s=190, name='Tile')
    inner += f"<div class='abs' style='left:0;right:0;top:330px;text-align:center'>{T('Gem Pile', 52, 'l', name='ItemName')}</div>"
    inner += f"<div class='abs' style='left:0;right:0;top:396px;text-align:center'>{T('+25 Gems', 36, 's', 'f-blue', name='Amount')}</div>"
    inner += plate(180, 462, 400, 96, 'green', T('Claim', 46, 'l'), name='BtnClaim')
    head = plate(-5, -5, 760, 96, 'blue', T('RARE!', 56, 'l', 'f-blue', name='Title'), 'head', style='left:-5px;top:-5px')
    return grp('RewardPopup', f"<div class='glass' data-n='Card' style='left:{x}px;top:{y}px;width:760px;height:590px'>{head}{inner}</div>", 'TL')


def s_templates():
    out = "<div class='abs fill' style='background:linear-gradient(#1d3a33,#142620)'></div>"
    out += "<div class='cap' style='left:60px;top:30px'>Runtime templates: game code clones these (UIKit.template)</div>"
    out += toast(60, 100, 'info', 'info', 'Tip: tap a pet to equip it', 'Toast_info')
    out += toast(60, 210, 'good', 'check', 'Speed Coil bought!', 'Toast_good')
    out += toast(60, 320, 'error', 'warning', 'Need 950 more coins', 'Toast_error')
    out += toast(60, 430, 'cash', 'coin', '+500 coins', 'Toast_cash')
    out += confirm(60, 600) + reward_popup(1000, 100)
    # full-screen scrim behind dialogs (runtime sets Size = 1,1 scale; Active so clicks never reach the world)
    out += grp('Scrim', box(1000, 740, 300, 160, "<div class='cap' style='left:8px;top:60px'>Scrim (full screen)</div>", '',
                            'background:rgba(0,8,12,.5)', name='Scrim'), 'TL')
    # loading card for the ReplicatedFirst LoadingScreen (bar LoadBar + fill F, label Status)
    out += grp('Loading', box(1340, 740, 520, 200, f"<div class='abs' style='left:0;right:0;top:24px;text-align:center'>{T('My Game', 56, 'l', 'f-gold', name='Title')}</div>"
               + bar(40, 110, 440, 30, .45, 'g-gold', 'LoadBar')
               + f"<div class='abs' style='left:0;right:0;top:150px;text-align:center'>{T('Loading...', 24, 'xs', name='Status')}</div>", 'glass', name='Card'), 'TL')
    return out


# ---------------------------------------------------------------- states sheet (review only)
def s_states():
    out = "<div class='abs fill' style='background:linear-gradient(#1d3a33,#142620)'></div>"
    y = 40
    out += f"<div class='cap' style='left:40px;top:{y}px'>Buttons: normal / hover / pressed / locked-unaffordable</div>"
    for i, c in enumerate(['green', 'red', 'blue', 'yellow']):
        for j, st in enumerate(['', 'st-hover', 'st-press', 'off']):
            out += plate(40 + j * 300 + (i // 2) * 0, 100 + i * 120, 260, 92, c, T(['Buy', 'Delete', 'Open', 'Claim'][i], 42, 's'), st)
    out += f"<div class='cap' style='left:1260px;top:{y}px'>Cards: open / owned / locked / unaffordable</div>"
    for i, c in enumerate(CARDS):
        out += card(1260 + (i % 2) * 320, 100 + (i // 2) * 460, *c)
    out += "<div class='cap' style='left:40px;top:600px'>Empty state (inventory with nothing in it)</div>"
    out += box(40, 650, 560, 300, flex(icn('backpack', 110, extra='opacity:.6') + "<div style='width:24px'></div>" +
                                         T('No items yet: open a crate!', 30, 's', 'f-grey')), 'inset', 'flex-direction:column')
    out += "<div class='cap' style='left:640px;top:600px'>Full state (capacity chip, red only while full)</div>"
    out += box(640, 650, 520, 90, flex(icn('backpack', 64) + T('50 / 50', 40, 's', 'f-red') + T('FULL', 30, 'xs', 'f-red')), 'glass', 'gap:14px')
    out += "<div class='cap' style='left:640px;top:780px'>Badge (data-driven: only when something is actionable)</div>"
    out += I('shop', 660, 830, 120) + badge(744, 826, '!')
    out += "<div class='cap' style='left:40px;top:1000px'>Toasts: info / success / error / cash</div>"
    for i, (k, ic, t) in enumerate([('info', 'info', 'Tip: tap a pet to equip it'), ('good', 'check', 'Speed Coil bought!'),
                                    ('error', 'warning', 'Need 950 more coins'), ('cash', 'coin', '+500 coins')]):
        out += toast(40 + (i % 2) * 700, 1060 + (i // 2) * 110, k, ic, t, 'x').replace("class='abs fill grp'", "class='abs fill'")
    out += "<div class='cap' style='left:40px;top:1320px'>Phone HUD: see hud_phone.html</div>"
    return out


# ---------------------------------------------------------------- style sheet: reference -> tokens
def s_style():
    """The page to show the developer WITH the first screen: their reference on the left, what was read
    from it (palette, tokens) and the kit drawn in those tokens on the right."""
    out = "<div class='abs fill' style='background:#14181f'></div>"
    ref = 'ref.png' if os.path.exists(os.path.join(HERE, 'ref.png')) else ''
    out += "<div class='cap' style='left:40px;top:24px'>1. Reference (the developer's image)</div>"
    out += (f"<img class='abs' src='{ref}' style='left:40px;top:80px;width:820px;height:520px;object-fit:contain;background:#000;border-radius:12px'>"
            if ref else "<div class='rbx' style='left:40px;top:80px;width:820px;height:520px;border-radius:12px'>no ref.png: ask for a style reference (or default to stud)</div>")
    pal = 'ref_palette.png' if os.path.exists(os.path.join(HERE, 'ref_palette.png')) else ''
    out += "<div class='cap' style='left:40px;top:630px'>2. Read from it (read_reference.py): palette</div>"
    if pal:
        out += f"<img class='abs' src='{pal}' style='left:40px;top:680px;width:820px;object-fit:contain'>"
    css = open(os.path.join(HERE, 'style.css')).read() if os.path.exists(os.path.join(HERE, 'style.css')) else '/* no style.css yet */'
    out += (f"<pre class='abs' style='left:40px;top:850px;width:820px;height:210px;overflow:hidden;margin:0;padding:12px;background:#0b0e13;"
            f"border-radius:10px;font:600 15px var(--font2);color:#b9c4d0;white-space:pre-wrap'>{html.escape(css)}</pre>")
    out += f"<div class='cap' style='left:920px;top:24px'>3. Tokens drawn: preset styles/{STYLE}.css + style.css</div>"
    y = 90
    for i, c in enumerate(['green', 'blue', 'red', 'yellow', 'purple', 'grey']):
        out += plate(920 + (i % 3) * 330, y + (i // 3) * 110, 300, 90, c, T(c.capitalize(), 40, 's'))
    y = 330
    out += "<div class='cap' style='left:920px;top:310px'>button states: normal / hover / pressed / off</div>"
    for j, st in enumerate(['', 'st-hover', 'st-press', 'off']):
        out += plate(920 + j * 245, y + 40, 220, 84, 'green', T('Buy', 40, 's'), st)
    out += "<div class='cap' style='left:920px;top:480px'>text: sizes and fills</div>"
    out += box(920, 530, 960, 90, T('Title 64', 64, 'l') + "<span style='width:30px;display:inline-block'></span>" +
               T('$1.25K', 56, 'l', 'f-green') + "<span style='width:30px;display:inline-block'></span>" + T('Body 30', 30, 's', 'f-yellow'),
               style='display:flex;align-items:center')
    out += "<div class='cap' style='left:920px;top:640px'>panel + reward tiles + icons (your pack, outline variant) + bar + small plate</div>"
    inner = reward_tile(30, 40, 'trophy', '1', 'legendary') + reward_tile(30 + 0, 250, 'gem_blue', '25', 'rare', s=80)
    inner += I('gem', 320, 40, 110) + I('cash', 450, 40, 110) + I('crate', 580, 40, 110) + I('settings', 710, 40, 110)
    inner += bar(320, 190, 500, 34, .6, 'g-gold', 'Bar') + plate(320, 250, 300, 84, 'green', icn('coin', 46) + T('250', 40, 's'), 'sm')
    out += box(920, 690, 960, 360, inner, 'panel', 'border-radius:var(--panel-rad)')
    return out


# ---------------------------------------------------------------- page shell
JS = """
<script>
const q = new URLSearchParams(location.search);
if(q.get('style')) document.getElementById('preset').href='styles/'+q.get('style')+'.css';
function fit(){ const w=document.getElementById('wrap');
  if(q.has('raw')){ w.style.transform='none'; return; }
  const H=document.getElementById('stage').offsetHeight;
  const s=Math.min(innerWidth/1920, innerHeight/H); w.style.transform='scale('+s+')';
  w.style.left=((innerWidth-1920*s)/2)+'px'; w.style.top=((innerHeight-H*s)/2)+'px'; }
addEventListener('resize', fit); fit();
// autofit: an outlined label wider than its plate/tile/panel is squeezed (scaleX to .8, then font-size)
function autofit(){
  document.querySelectorAll('.ot').forEach(e=>{
    const c=e.closest('.plate,.tile,.inset,.panel,.glass'); if(!c) return;
    const cs=getComputedStyle(e.parentElement);
    const cr=c.getBoundingClientRect(), er=e.getBoundingClientRect(), k=cr.width/c.offsetWidth||1, pad=(c.classList.contains('plate')?14:8)*k;
    let avail, origin='left';
    if(cs.textAlign==='center'||cs.justifyContent==='center'){ avail=Math.min(e.parentElement.getBoundingClientRect().width, cr.width)-2*pad; origin='center'; }
    else if(cs.textAlign==='right'||cs.justifyContent==='flex-end'){ avail=er.right-cr.left-pad; origin='right'; }
    else { avail=cr.right-pad-er.left; }
    if(er.width<=avail) return;
    let sc=avail/er.width;
    if(sc<.8){ const fs=parseFloat(getComputedStyle(e).fontSize); e.style.fontSize=(fs*sc/.8)+'px'; sc=.8; }
    e.style.transform='scaleX('+sc.toFixed(3)+')'; e.style.transformOrigin=origin+' center';
  });
}
document.fonts.ready.then(autofit);
// ?check: outline text that spills out of its box + list broken images (also callable from devtools)
window.checkOverflow = function(){
  const bad=[]; const st=document.getElementById('stage').getBoundingClientRect();
  document.querySelectorAll('.ot').forEach(e=>{
    const r=e.getBoundingClientRect(); const c=e.closest('.plate,.tile,.inset,.panel,.glass');
    const k=(r.width/e.offsetWidth)||1;
    if(c){ const b=c.getBoundingClientRect();
      if(r.left<b.left-3*k||r.right>b.right+3*k||r.top<b.top-12*k||r.bottom>b.bottom+12*k){bad.push(e.dataset.t); e.classList.add('overflowing');} }
    if(r.right>st.right+1||r.left<st.left-1||r.bottom>st.bottom+1){ bad.push('STAGE:'+e.dataset.t); e.classList.add('overflowing'); }
  });
  const broken=[...document.images].filter(i=>i.complete && !i.naturalWidth).map(i=>i.getAttribute('src'));
  return {overflow:bad, broken};
};
if(q.has('check')) document.fonts.ready.then(()=>setTimeout(()=>console.log(JSON.stringify(checkOverflow())), 300));
</script>"""


def page(title, body, h=1080):
    return (f"<!doctype html><html><head><meta charset='utf-8'><title>{title}</title>"
            f"<meta name='viewport' content='width=device-width,initial-scale=1'>{FONTS}"
            f"<link rel='stylesheet' href='kit.css'><link id='preset' rel='stylesheet' href='styles/{STYLE}.css'>"
            + ("<link rel='stylesheet' href='style.css'>" if os.path.exists(os.path.join(HERE, 'style.css')) else '')
            + "</head><body>"
            f"<div id='wrap'><div id='stage' style='height:{h}px'>{body}</div></div>{JS}</body></html>")


SCREENS = [  # (file, title, description, fn, height)
    ('style.html', 'Style: reference -> tokens', 'The reference, what was read from it, and the kit in those tokens', s_style, 1080),
    ('hud.html', 'HUD', 'Cash + gems, menu buttons, next-goal pill', s_hud, 1080),
    ('hud_phone.html', 'HUD (phone)', 'Bigger targets, Roblox thumbstick/jump kept clear', s_hud_phone, 1080),
    ('shop.html', 'Shop', 'Tabs + cards: open / owned / locked / unaffordable', s_shop, 1080),
    ('crate.html', 'Crate opening', 'Single reel, markers above and below, prize unobstructed', s_crate, 1080),
    ('crate_odds.html', 'Crate odds', 'Odds from the same table the server rolls', s_crate_odds, 1080),
    ('templates.html', 'Runtime templates', 'Toasts, confirm dialog, reward popup', s_templates, 1080),
    ('states.html', 'All states', 'Every element in every state', s_states, 1400),
]


def index():
    cards = ''
    for fname, title, desc, _, h in SCREENS:
        cards += (f"<a class='card' href='{fname}'><div class='frame' style='aspect-ratio:1920/{h}'>"
                  f"<iframe src='{fname}?raw' loading='lazy' tabindex='-1' scrolling='no' style='height:{h}px'></iframe></div>"
                  f"<h3>{title}</h3><p>{desc}</p></a>")
    return f"""<!doctype html><html><head><meta charset='utf-8'><title>UI Screens</title>
<meta name='viewport' content='width=device-width,initial-scale=1'>{FONTS}
<style>
:root{{--bg:#0f1a14;--card:#16241c;--ink:#eef6f0;--mute:#9fb3a6;--line:#2a3d31}}
body{{margin:0;background:var(--bg);color:var(--ink);font-family:'Montserrat',sans-serif}}
header{{padding:24px 16px 8px}} h1{{margin:0;font-weight:900;font-size:30px}} header p{{color:var(--mute);margin:6px 0 0;font-weight:600}}
.grid{{display:grid;grid-template-columns:repeat(auto-fill,minmax(300px,1fr));gap:16px;padding:16px}}
.card{{display:block;background:var(--card);border:1px solid var(--line);border-radius:14px;overflow:hidden;color:inherit;text-decoration:none}}
.frame{{position:relative;width:100%;overflow:hidden;background:#000}}
.frame iframe{{position:absolute;left:0;top:0;width:1920px;border:0;transform-origin:0 0;pointer-events:none}}
h3{{margin:12px 14px 2px;font-size:18px}} .card p{{margin:0 14px 14px;color:var(--mute);font-size:13px;font-weight:600}}
</style></head><body><header><h1>UI Screens</h1><p>{len(SCREENS)} pages at 1920 wide. Click one to open it full size.</p></header>
<div class='grid'>{cards}</div>
<script>function sz(){{document.querySelectorAll('.frame').forEach(f=>{{f.firstChild.style.transform='scale('+(f.clientWidth/1920)+')'}})}}addEventListener('resize',sz);sz();</script>
</body></html>"""


if __name__ == '__main__':
    missing = [p for p in ('stud.png', 'icons') if not os.path.exists(os.path.join(HERE, p))]
    if missing:
        print('WARN missing', missing, '- see the usage lines at the top of this file')
    for fname, title, desc, fn, h in SCREENS:
        with open(os.path.join(HERE, fname), 'w') as f:
            f.write(page(title, fn(), h))
    with open(os.path.join(HERE, 'index.html'), 'w') as f:
        f.write(index())
    print('wrote', len(SCREENS), 'pages + index.html')
