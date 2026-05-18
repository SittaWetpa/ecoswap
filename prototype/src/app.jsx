// ─────────────────────────────────────────────────────────────
// EcoSwap — App shell & navigation state machine
// ─────────────────────────────────────────────────────────────

const TWEAK_DEFAULTS = /*EDITMODE-BEGIN*/{
  "accent": "#1D9E75",
  "density": "regular",
  "impactVariant": "dashboard",
  "showEmpties": false,
  "showIncomingInterest": false,
  "tab": "discover"
}/*EDITMODE-END*/;

const ACCENT_PRESETS = {
  '#1D9E75': { dark: '#0F6E56', soft: '#E1F5EE' }, // EcoSwap green
  '#2A6FDB': { dark: '#1A4A99', soft: '#E1ECFB' }, // Trust blue
  '#7A5AE0': { dark: '#4F38A1', soft: '#EDE7FC' }, // Reuse violet
  '#C46A2A': { dark: '#8A4A1B', soft: '#F8E8D8' }, // Warm terracotta
};

const DENSITY_PADDINGS = { compact: 0.85, regular: 1, comfy: 1.15 };

function applyAccent(hex) {
  const preset = ACCENT_PRESETS[hex] || ACCENT_PRESETS['#1D9E75'];
  const r = document.documentElement.style;
  r.setProperty('--green-primary', hex);
  r.setProperty('--green-dark', preset.dark);
  r.setProperty('--green-soft', preset.soft);
}

function applyDensity(d) {
  document.documentElement.style.setProperty('--density', DENSITY_PADDINGS[d] || 1);
}

// ─── Main app ───────────────────────────────────────────────
function App() {
  const [t, setTweak] = useTweaks(TWEAK_DEFAULTS);
  const [route, setRoute] = React.useState({ name: 'splash' });
  const [tab, setTab] = React.useState(t.tab || 'discover');
  const [deck, setDeck] = React.useState(PEOPLE.slice());
  const [proposal, setProposal] = React.useState(null);
  const [activeChat, setActiveChat] = React.useState(null);
  const [toast, setToast] = React.useState(null);

  React.useEffect(() => applyAccent(t.accent), [t.accent]);
  React.useEffect(() => applyDensity(t.density), [t.density]);

  // Navigate helpers
  const go = (name, payload = {}) => setRoute({ name, ...payload });
  const goTab = (next) => { setTab(next); setRoute({ name: 'main' }); };

  // Liking from discover -> show user detail OR jump to picker
  const onLikeFromDiscover = (person) => {
    // Quick-tap from button = open detail; for prototype clarity let's go to picker
    setRoute({ name: 'picker', person });
  };

  const onSendProposal = (picks) => {
    const person = route.person;
    // Anonymous nudge: bounce back to discover with a toast.
    // (Match screen only fires later, after both parties swipe right.)
    setProposal({ person, ...picks });
    setRoute({ name: 'main' });
    showToast(`Interest sent to ${person?.name} · anonymous until she swipes back`);
  };

  const showToast = (msg) => {
    setToast(msg);
    clearTimeout(showToast._t);
    showToast._t = setTimeout(() => setToast(null), 2000);
  };

  // Persistent shell: top-level screens have bottom nav
  const inTopLevel = route.name === 'main';
  const inFlowScreen = ['detail','picker','match','chat','qr','myitems','upload','edit','editprofile'].includes(route.name);

  // Editable profile — kept in app state so changes from editprofile screen
  // round-trip back into the Profile view.
  const [profile, setProfile] = React.useState({
    name: 'Nong',
    district: { thai: 'บางมด', en: 'Bang Mod', city: 'Bangkok' },
    bio: 'KMUTT student, decluttering before the semester ends.',
  });

  let body;
  switch (route.name) {
    case 'splash':
      body = <SplashScreen onContinue={() => go('auth')} />;
      break;
    case 'auth':
      body = <AuthScreen onSubmit={() => go('setup')} onBack={() => go('splash')} mode="signup" onModeChange={() => {}} />;
      break;
    case 'setup':
      body = <SetupScreen onDone={() => go('main')} onBack={() => go('auth')} />;
      break;
    case 'main': {
      if (tab === 'discover') {
        // When the "incoming interest" tweak is on, surface people who've
        // declared interest at the top of the deck, each with a badge naming
        // which of Fah's items they want.
        const INTEREST_MOCK = {
          ploy: itemById('kettle'), // Ploy wants Fah's Electric kettle
          beam: itemById('lamp'),   // Beam wants Fah's Desk lamp
          nan:  itemById('kettle'), // Nan also wants the kettle
        };
        const interestMap = t.showIncomingInterest ? INTEREST_MOCK : null;
        const orderedDeck = t.showIncomingInterest
          ? [
              ...deck.filter(p => INTEREST_MOCK[p.id]),
              ...deck.filter(p => !INTEREST_MOCK[p.id]),
            ]
          : deck;
        body = <DiscoverScreen
          density={t.density}
          deck={orderedDeck} setDeck={setDeck}
          empty={t.showEmpties}
          interestMap={interestMap}
          onLike={onLikeFromDiscover}
          onNavigate={(name, p) => go(name, p)}
        />;
      } else if (tab === 'chats') {
        body = <ChatsScreen empty={t.showEmpties} onOpen={(c) => { setActiveChat(c); go('chat'); }} />;
      } else if (tab === 'impact') {
        body = <ImpactScreen variant={t.impactVariant} empty={t.showEmpties} />;
      } else if (tab === 'profile') {
        body = <ProfileScreen
          profile={profile}
          onMyItems={() => go('myitems')}
          onEdit={() => go('editprofile')}
          onLogout={() => go('splash')}
        />;
      }
      break;
    }
    case 'detail':
      body = <UserDetailScreen person={route.person} onBack={() => go('main')}
              onLike={(p) => go('picker', { person: p })} />;
      break;
    case 'picker':
      // Render Discover behind so the 40% backdrop shows the feed underneath.
      body = (
        <React.Fragment>
          <DiscoverScreen
            density={t.density}
            deck={deck} setDeck={setDeck}
            empty={false}
            onLike={() => {}}
            onNavigate={() => {}}
          />
          <PickerScreen person={route.person} onCancel={() => go('main')} onSend={onSendProposal} />
        </React.Fragment>
      );
      break;
    case 'match':
      body = <MatchScreen proposal={proposal} onChat={() => {
        // Pretend a new chat exists for this proposal
        const tempChat = {
          id: 'new-' + proposal.person.id,
          person: proposal.person.id,
          trade: { mine: proposal.myPick.id, theirs: proposal.theirPick.id },
        };
        setActiveChat(tempChat);
        go('chat');
      }} onKeep={() => go('main')} />;
      break;
    case 'chat':
      body = <ChatScreen chat={activeChat} onBack={() => go('main')}
              onReadyExchange={() => go('qr')} />;
      break;
    case 'qr':
      body = <QRScreen chat={activeChat} onBack={() => go('chat')} onComplete={() => {
        setTab('impact');
        go('main');
        showToast('Swap recorded · impact updated');
      }} />;
      break;
    case 'myitems':
      body = <MyItemsScreen
        onBack={() => go('main')}
        onAdd={() => go('upload')}
        onEdit={(item) => go('edit', { item })}
      />;
      break;
    case 'upload':
      body = <UploadItemScreen
        onBack={() => go('myitems')}
        onSubmit={(draft) => {
          // Commit the new item into the global ITEMS array so MyItems shows it.
          const id = 'mine-' + Date.now();
          ITEMS.push({
            id, owner: 'me',
            name: draft.name,
            cat: draft.cat,
            cond: draft.cond,
            swatch: draft.photo?.swatch || '#9AAE9C',
          });
          go('myitems');
          showToast(`Added \u201c${draft.name}\u201d to your swaps`);
        }}
      />;
      break;
    case 'editprofile':
      body = <EditProfileScreen
        initial={profile}
        onBack={() => go('main')}
        onSave={(next) => {
          setProfile(p => ({ ...p, ...next }));
          setTab('profile');
          go('main');
          showToast('Profile updated');
        }}
      />;
      break;
    case 'edit': {
      const it = route.item;
      body = <UploadItemScreen
        title="Edit item"
        submitLabel="Save changes"
        onBack={() => go('myitems')}
        initial={{
          photo: 'placeholder',
          swatch: it.swatch,
          photoLabel: `${it.name.toLowerCase()} photo`,
          name: it.name,
          cat: it.cat,
          cond: it.cond,
          weight: it.weight != null ? String(it.weight) : '',
          desc: it.desc || '',
          want: it.want || '',
        }}
        onSubmit={(draft) => {
          // Mutate the existing item in place so MyItems reflects the edit.
          const idx = ITEMS.findIndex(x => x.id === it.id);
          if (idx >= 0) {
            ITEMS[idx] = {
              ...ITEMS[idx],
              name: draft.name,
              cat: draft.cat,
              cond: draft.cond,
              weight: draft.weight,
              desc: draft.desc,
              want: draft.want,
            };
          }
          go('myitems');
          showToast(`Saved changes to \u201c${draft.name}\u201d`);
        }}
        onDelete={() => {
          const idx = ITEMS.findIndex(x => x.id === it.id);
          const removedName = it.name;
          if (idx >= 0) ITEMS.splice(idx, 1);
          go('myitems');
          showToast(`Deleted \u201c${removedName}\u201d`);
        }}
        deleteLabel="Delete item"
      />;
      break;
    }
    default:
      body = null;
  }

  const showBottomNav = inTopLevel;

  return (
    <div style={{ display: 'flex', gap: 32, alignItems: 'flex-start' }}>
      {/* Phone */}
      <PhoneFrame>
        <div style={{ flex: 1, display: 'flex', flexDirection: 'column', position: 'relative', minHeight: 0, background: 'var(--surface)' }}>
          <div style={{ flex: 1, minHeight: 0, display: 'flex', flexDirection: 'column' }}>
            {body}
          </div>
          {showBottomNav && <BottomNav active={tab} onChange={goTab} />}
          <Toast show={!!toast}>{toast}</Toast>
        </div>
      </PhoneFrame>

      {/* Side rail of quick-nav demo controls — visible always so user can jump around */}
      <DemoRail
        route={route} tab={tab} setTab={goTab} go={go}
        setActiveChat={setActiveChat} setProposal={setProposal}
        showIncomingInterest={t.showIncomingInterest}
        setIncomingInterest={(v) => setTweak('showIncomingInterest', v)}
      />

      {/* Tweaks panel */}
      <TweaksPanel title="Tweaks">
        <TweakSection label="Theme" />
        <TweakColor label="Accent" value={t.accent}
          options={Object.keys(ACCENT_PRESETS)}
          onChange={(v) => setTweak('accent', v)} />
        <TweakRadio label="Density" value={t.density}
          options={['compact', 'regular', 'comfy']}
          onChange={(v) => setTweak('density', v)} />

        <TweakSection label="Impact Tracker variant" />
        <TweakRadio label="Layout" value={t.impactVariant}
          options={['dashboard', 'timeline', 'compare']}
          onChange={(v) => { setTweak('impactVariant', v); setTab('impact'); go('main'); }} />

        <TweakSection label="States" />
        <TweakToggle label="Show empty states" value={t.showEmpties}
          onChange={(v) => setTweak('showEmpties', v)} />
        <TweakToggle label="Incoming interest on Discover" value={t.showIncomingInterest}
          onChange={(v) => { setTweak('showIncomingInterest', v); setTab('discover'); go('main'); }} />
      </TweaksPanel>
    </div>
  );
}

// ─── Demo navigation rail (right beside phone) ───────────────
function DemoRail({ route, tab, setTab, go, setActiveChat, setProposal, showIncomingInterest, setIncomingInterest }) {
  const sections = [
    {
      title: 'Onboarding',
      items: [
        { label: 'Splash',        active: route.name === 'splash', go: () => go('splash') },
        { label: 'Sign up',       active: route.name === 'auth',   go: () => go('auth') },
        { label: 'Profile setup', active: route.name === 'setup',  go: () => go('setup') },
      ]
    },
    {
      title: 'Core loop',
      items: [
        { label: 'Discover',     active: route.name === 'main' && tab === 'discover' && !showIncomingInterest, go: () => { setIncomingInterest?.(false); setTab('discover'); } },
        { label: 'Discover · incoming interest', active: route.name === 'main' && tab === 'discover' && showIncomingInterest, go: () => { setIncomingInterest?.(true); setTab('discover'); } },
        { label: 'User detail',  active: route.name === 'detail',  go: () => go('detail', { person: PEOPLE[0] }) },
        { label: 'Item picker',  active: route.name === 'picker',  go: () => go('picker', { person: PEOPLE[1] }) },
        { label: 'Match',        active: route.name === 'match',   go: () => {
          setProposal({ person: PEOPLE[1], myPick: itemById('mine-mug'), theirPick: itemById('kettle') });
          go('match');
        } },
        { label: 'Chats',        active: route.name === 'main' && tab === 'chats',    go: () => setTab('chats') },
        { label: 'Match chat',   active: route.name === 'chat',    go: () => {
          setActiveChat(CHATS[0]);
          go('chat');
        } },
        { label: 'QR exchange',  active: route.name === 'qr',      go: () => {
          setActiveChat(CHATS[0]);
          go('qr');
        } },
      ]
    },
    {
      title: 'Outcome',
      items: [
        { label: 'Impact',  active: route.name === 'main' && tab === 'impact',  go: () => setTab('impact') },
        { label: 'My items', active: route.name === 'myitems', go: () => go('myitems') },
        { label: 'Add item', active: route.name === 'upload', go: () => go('upload') },
        { label: 'Edit item', active: route.name === 'edit', go: () => go('edit', { item: itemById('mine-jacket') }) },
        { label: 'Profile', active: route.name === 'main' && tab === 'profile', go: () => setTab('profile') },
        { label: 'Edit profile', active: route.name === 'editprofile', go: () => go('editprofile') },
      ]
    }
  ];
  return (
    <div style={{
      width: 200, padding: '8px 0', fontFamily: 'Inter',
      maxHeight: 880, overflow: 'auto', flexShrink: 0,
    }} className="phone-scroll">
      <div style={{ padding: '4px 12px 12px' }}>
        <Wordmark size={16} />
        <div style={{ fontSize: 11, color: 'var(--text-tertiary)', marginTop: 6, lineHeight: 1.4 }}>
          Tap a screen to jump to it. Swipe works on Discover.
        </div>
      </div>
      {sections.map(sec => (
        <div key={sec.title} style={{ marginTop: 8 }}>
          <div style={{ padding: '6px 12px', fontSize: 10, fontWeight: 600, color: 'var(--text-tertiary)', letterSpacing: 0.6, textTransform: 'uppercase' }}>{sec.title}</div>
          {sec.items.map(it => (
            <button key={it.label} onClick={it.go} style={{
              width: '100%', textAlign: 'left',
              padding: '7px 12px', border: 'none',
              background: it.active ? 'rgba(29,158,117,0.10)' : 'transparent',
              color: it.active ? 'var(--green-primary)' : 'var(--text-primary)',
              fontSize: 13, fontWeight: it.active ? 600 : 400,
              cursor: 'pointer', borderRadius: 6,
              display: 'flex', alignItems: 'center', gap: 6,
            }}>
              <span style={{
                width: 4, height: 4, borderRadius: 4,
                background: it.active ? 'var(--green-primary)' : 'var(--border)',
              }} />
              {it.label}
            </button>
          ))}
        </div>
      ))}
    </div>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<App />);
