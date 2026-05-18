// Upload Item — Add an item form.
// Used in two contexts:
//  1) Live in the prototype (interactive): pass onBack + onSubmit.
//  2) Design canvas: pass `readonly` + an `initial` object to render a static
//     frame for review.

const CONDITIONS = ['New', 'Like new', 'Good', 'Used'];

const CATEGORY_OPTIONS = [
  { id: 'clothing',    label: 'Clothing',    hint: 'Jackets, bags, accessories…' },
  { id: 'books',       label: 'Books',       hint: 'Textbooks, novels, magazines' },
  { id: 'kitchenware', label: 'Kitchenware', hint: 'Mugs, cookware, gadgets' },
  { id: 'household',   label: 'Household',   hint: 'Lamps, plants, décor' },
  { id: 'electronics', label: 'Electronics', hint: 'Small gadgets, cables, parts' },
  { id: 'furniture',   label: 'Furniture',   hint: 'Chairs, desks, shelves' },
  { id: 'other',       label: 'Other',       hint: 'Anything that doesn\'t fit above' },
];

// — Atom: field label —
const FieldLabel = ({ children }) => (
  <div style={{
    fontSize: 12, fontWeight: 500, color: 'var(--text-secondary)',
    letterSpacing: 0.1, marginBottom: 8,
  }}>{children}</div>
);

// — Atom: text input (real or static) —
const TextField = ({ value, onChange, placeholder, readonly }) => {
  const [focus, setFocus] = React.useState(false);
  if (readonly) {
    return (
      <div style={{
        width: '100%', minHeight: 48, padding: '12px 14px',
        background: 'var(--surface-alt)',
        border: '1px solid var(--border)',
        borderRadius: 8, fontSize: 15,
        display: 'flex', alignItems: 'center',
        color: value ? 'var(--text-primary)' : 'var(--text-tertiary)',
        boxSizing: 'border-box',
      }}>{value || placeholder}</div>
    );
  }
  return (
    <input
      value={value || ''}
      onChange={(e) => onChange(e.target.value)}
      placeholder={placeholder}
      onFocus={() => setFocus(true)} onBlur={() => setFocus(false)}
      style={{
        width: '100%', minHeight: 48, padding: '12px 14px',
        background: 'var(--surface-alt)',
        border: focus ? '1.5px solid var(--green-primary)' : '1px solid var(--border)',
        borderRadius: 8, fontSize: 15, color: 'var(--text-primary)',
        outline: 'none', boxSizing: 'border-box',
      }}
    />
  );
};

// — Atom: textarea (real or static) —
const TextArea = ({ value, onChange, placeholder, rows = 4, readonly }) => {
  const [focus, setFocus] = React.useState(false);
  if (readonly) {
    return (
      <div style={{
        width: '100%', minHeight: rows * 22 + 24, padding: '12px 14px',
        background: 'var(--surface-alt)',
        border: '1px solid var(--border)',
        borderRadius: 8, fontSize: 15, lineHeight: 1.45,
        color: value ? 'var(--text-primary)' : 'var(--text-tertiary)',
        boxSizing: 'border-box',
        whiteSpace: 'pre-wrap',
      }}>{value || placeholder}</div>
    );
  }
  return (
    <textarea
      value={value || ''}
      onChange={(e) => onChange(e.target.value)}
      placeholder={placeholder}
      rows={rows}
      onFocus={() => setFocus(true)} onBlur={() => setFocus(false)}
      style={{
        width: '100%', padding: '12px 14px',
        background: 'var(--surface-alt)',
        border: focus ? '1.5px solid var(--green-primary)' : '1px solid var(--border)',
        borderRadius: 8, fontSize: 15, lineHeight: 1.45,
        color: 'var(--text-primary)',
        outline: 'none', boxSizing: 'border-box',
        resize: 'none',
        fontFamily: 'inherit',
      }}
    />
  );
};

// — Photo field. When filled, show a striped placeholder + Change link. —
const PhotoField = ({ value, swatch, label, onToggle, readonly }) => {
  if (!value) {
    return (
      <div
        onClick={readonly ? undefined : onToggle}
        style={{
          width: '100%', aspectRatio: '1 / 1',
          background: 'var(--surface-alt)',
          border: '1px dashed var(--border)',
          borderRadius: 12,
          display: 'flex', flexDirection: 'column',
          alignItems: 'center', justifyContent: 'center',
          gap: 8,
          cursor: readonly ? 'default' : 'pointer',
        }}>
        <IconCamera size={32} color="var(--text-tertiary)" />
        <div style={{ fontSize: 15, color: 'var(--text-secondary)', fontWeight: 500 }}>
          Add a photo
        </div>
        <div style={{ fontSize: 12, color: 'var(--text-tertiary)' }}>
          Tap to use camera or library
        </div>
      </div>
    );
  }
  const sw = swatch || '#8B6F4E';
  return (
    <div style={{
      width: '100%', aspectRatio: '1 / 1',
      borderRadius: 12, overflow: 'hidden',
      position: 'relative',
      background: `repeating-linear-gradient(135deg, ${sw}33 0 10px, ${sw}1f 10px 20px), ${sw}3a`,
      border: '1px solid var(--border)',
    }}>
      <div style={{
        position: 'absolute', inset: 0,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        fontFamily: 'JetBrains Mono, monospace',
        fontSize: 13, color: '#fff', mixBlendMode: 'difference',
        fontWeight: 500, letterSpacing: 0.2, textAlign: 'center', padding: '0 16px',
      }}>
        {label || 'item photo'}
      </div>
      <button
        onClick={readonly ? undefined : onToggle}
        style={{
          position: 'absolute', right: 12, bottom: 12,
          background: 'rgba(255,255,255,0.92)',
          backdropFilter: 'blur(4px)',
          padding: '6px 12px', borderRadius: 9999, border: 'none',
          display: 'inline-flex', alignItems: 'center', gap: 6,
          fontSize: 13, fontWeight: 600,
          color: 'var(--green-primary)',
          boxShadow: '0 1px 3px rgba(0,0,0,0.08)',
          cursor: readonly ? 'default' : 'pointer',
        }}>
        <IconCamera size={14} />
        Change photo
      </button>
    </div>
  );
};

// — Condition pill row —
const ConditionPills = ({ value, onChange, readonly }) => (
  <div style={{ display: 'flex', gap: 8 }}>
    {CONDITIONS.map(c => {
      const on = c === value;
      return (
        <button
          key={c}
          onClick={readonly ? undefined : () => onChange(c)}
          style={{
            padding: '8px 16px',
            borderRadius: 9999,
            fontSize: 14, fontWeight: 500, lineHeight: 1.2,
            background: on ? 'var(--green-soft)' : 'var(--surface-alt)',
            color: on ? 'var(--green-dark)' : 'var(--text-secondary)',
            border: `1px solid ${on ? 'var(--green-primary)' : 'var(--border)'}`,
            whiteSpace: 'nowrap',
            cursor: readonly ? 'default' : 'pointer',
            fontFamily: 'inherit',
          }}>{c}</button>
      );
    })}
  </div>
);

// — Category tap-row —
const CategoryRow = ({ value, onOpen, readonly }) => {
  const label = value ? (CATEGORY[value]?.label || value) : null;
  return (
    <button
      onClick={readonly ? undefined : onOpen}
      style={{
        width: '100%', minHeight: 48, padding: '12px 14px',
        background: 'var(--surface-alt)',
        border: '1px solid var(--border)',
        borderRadius: 8, fontSize: 15,
        display: 'flex', alignItems: 'center', justifyContent: 'space-between',
        boxSizing: 'border-box', cursor: readonly ? 'default' : 'pointer',
        fontFamily: 'inherit', textAlign: 'left',
      }}>
      <span style={{ color: label ? 'var(--text-primary)' : 'var(--text-tertiary)' }}>
        {label || 'Select a category'}
      </span>
      <IconChevR size={20} color="var(--text-secondary)" />
    </button>
  );
};

// — Weight field (with kg suffix) —
const WeightField = ({ value, onChange, readonly }) => {
  const [focus, setFocus] = React.useState(false);
  if (readonly) {
    return (
      <div style={{
        width: '100%', minHeight: 48, padding: '12px 14px',
        background: 'var(--surface-alt)',
        border: '1px solid var(--border)',
        borderRadius: 8, fontSize: 15,
        display: 'flex', alignItems: 'center', justifyContent: 'space-between',
        boxSizing: 'border-box',
      }}>
        <span style={{ color: value ? 'var(--text-primary)' : 'var(--text-tertiary)' }}>
          {value || 'approx. weight (default: 0.5)'}
        </span>
        <span style={{ fontSize: 13, color: 'var(--text-tertiary)' }}>kg</span>
      </div>
    );
  }
  return (
    <div style={{
      width: '100%', minHeight: 48, padding: '0 14px',
      background: 'var(--surface-alt)',
      border: focus ? '1.5px solid var(--green-primary)' : '1px solid var(--border)',
      borderRadius: 8,
      display: 'flex', alignItems: 'center',
      boxSizing: 'border-box',
    }}>
      <input
        type="text" inputMode="decimal"
        value={value || ''}
        onChange={(e) => onChange(e.target.value)}
        placeholder="approx. weight (default: 0.5)"
        onFocus={() => setFocus(true)} onBlur={() => setFocus(false)}
        style={{
          flex: 1, minWidth: 0, height: 46, padding: 0,
          background: 'transparent', border: 'none', outline: 'none',
          fontSize: 15, color: 'var(--text-primary)',
        }}
      />
      <span style={{ fontSize: 13, color: 'var(--text-tertiary)', marginLeft: 8 }}>kg</span>
    </div>
  );
};

// — Bottom sheet category picker —
const CategoryPicker = ({ open, value, onPick, onClose }) => (
  <Sheet open={open} onClose={onClose} height="60%">
    <div style={{ padding: '8px 16px 4px', flexShrink: 0 }}>
      <div style={{ fontSize: 18, fontWeight: 600, color: 'var(--text-primary)' }}>
        Pick a category
      </div>
      <div style={{ fontSize: 13, color: 'var(--text-secondary)', marginTop: 4 }}>
        Helps others find your item, and how we estimate impact.
      </div>
    </div>
    <div className="phone-scroll" style={{ flex: 1, overflow: 'auto', padding: '12px 8px 24px' }}>
      {CATEGORY_OPTIONS.map(opt => {
        const on = value === opt.id;
        return (
          <button key={opt.id} onClick={() => { onPick(opt.id); onClose(); }} style={{
            width: '100%', padding: '14px 12px', border: 'none',
            background: on ? 'var(--green-soft)' : 'transparent',
            borderRadius: 10,
            display: 'flex', alignItems: 'center', justifyContent: 'space-between',
            gap: 12, cursor: 'pointer', fontFamily: 'inherit', textAlign: 'left',
            marginBottom: 2,
          }}>
            <div>
              <div style={{ fontSize: 15, fontWeight: 500, color: 'var(--text-primary)' }}>{opt.label}</div>
              <div style={{ fontSize: 12, color: 'var(--text-secondary)', marginTop: 2 }}>{opt.hint}</div>
            </div>
            {on && <IconCheck size={20} color="var(--green-primary)" />}
          </button>
        );
      })}
    </div>
  </Sheet>
);

// — Whole upload screen. —
// Props:
//   onBack(): close form
//   onSubmit(item): commit item and close
//   initial: optional defaults (used by canvas)
//   readonly: render all controls as static (no interaction)
const UploadItemScreen = ({
  onBack, onSubmit, initial = {}, readonly = false,
  title = 'Add an item',
  submitLabel = 'Add to my swaps',
  onDelete,
  deleteLabel,
}) => {
  const [photo, setPhoto] = React.useState(initial.photo || null);
  const [name, setName] = React.useState(initial.name || '');
  const [cat, setCat] = React.useState(initial.cat || null);
  const [cond, setCond] = React.useState(initial.cond || null);
  const [weight, setWeight] = React.useState(initial.weight || '');
  const [desc, setDesc] = React.useState(initial.desc || '');
  const [want, setWant] = React.useState(initial.want || '');
  const [pickerOpen, setPickerOpen] = React.useState(false);

  // Required: photo, name, category, condition (description/want optional, weight optional)
  const valid = !!(photo && name.trim() && cat && cond);

  const submit = () => {
    if (!valid) return;
    onSubmit?.({
      photo, name: name.trim(),
      cat, cond,
      weight: weight ? parseFloat(weight) : null,
      desc: desc.trim() || null,
      want: want.trim() || null,
    });
  };

  return (
    <div style={{ flex: 1, display: 'flex', flexDirection: 'column', background: 'var(--surface)', minHeight: 0, position: 'relative' }}>
      {/* sticky top bar */}
      <div style={{
        background: 'var(--surface)',
        borderBottom: '1px solid var(--border)',
        flexShrink: 0,
      }}>
        <TopBar variant="hier" title={title} onBack={onBack} />
      </div>

      {/* scrollable form area */}
      <div className="phone-scroll" style={{
        flex: 1, overflow: 'auto',
        padding: '20px 16px 32px',
        display: 'flex', flexDirection: 'column', gap: 24,
      }}>
        {/* 1 — Photo */}
        <div>
          <FieldLabel>Photo</FieldLabel>
          <PhotoField
            value={photo}
            swatch={initial.swatch}
            label={initial.photoLabel}
            onToggle={() => setPhoto(photo ? null : (initial.swatch ? { swatch: initial.swatch } : 'placeholder'))}
            readonly={readonly}
          />
        </div>

        {/* 2 — Item name */}
        <div>
          <FieldLabel>What is it?</FieldLabel>
          <TextField value={name} onChange={setName} placeholder="e.g. Leather tote bag" readonly={readonly} />
        </div>

        {/* 3 — Category */}
        <div>
          <FieldLabel>Category</FieldLabel>
          <CategoryRow value={cat} onOpen={() => setPickerOpen(true)} readonly={readonly} />
        </div>

        {/* 4 — Condition */}
        <div>
          <FieldLabel>Condition</FieldLabel>
          <ConditionPills value={cond} onChange={setCond} readonly={readonly} />
        </div>

        {/* 5 — Weight */}
        <div>
          <FieldLabel>Weight</FieldLabel>
          <WeightField value={weight} onChange={setWeight} readonly={readonly} />
          <div style={{
            fontSize: 12, color: 'var(--text-tertiary)',
            marginTop: 4, lineHeight: 1.5,
          }}>
            Used to estimate the CO₂ impact of your swap. We'll use a typical weight for the category if you skip this.
          </div>
        </div>

        {/* 6 — Description */}
        <div>
          <FieldLabel>Description (optional)</FieldLabel>
          <TextArea
            value={desc} onChange={setDesc} rows={4} readonly={readonly}
            placeholder={"Anything worth mentioning — brand, size, why you're letting it go…"}
          />
        </div>

        {/* 7 — Wanted in exchange */}
        <div>
          <FieldLabel>What would you like in return?</FieldLabel>
          <TextArea
            value={want} onChange={setWant} rows={3} readonly={readonly}
            placeholder="e.g. books, kitchenware, or something useful for a dorm"
          />
        </div>

        <div style={{ height: 16 }} />
      </div>

      {/* sticky bottom submit (+ optional destructive action) */}
      <div style={{
        background: 'var(--surface)',
        borderTop: '1px solid var(--border)',
        padding: '16px',
        flexShrink: 0,
        display: 'flex', flexDirection: 'column', gap: 8,
      }}>
        <Button disabled={!valid} onClick={submit}>{submitLabel}</Button>
        {onDelete && (
          <Button
            variant="destructive"
            onClick={readonly ? undefined : onDelete}
            icon={<IconTrash size={18} />}
            style={{ fontWeight: 600 }}
          >
            {deleteLabel || 'Delete item'}
          </Button>
        )}
      </div>

      {/* Category bottom sheet */}
      {!readonly && (
        <CategoryPicker
          open={pickerOpen}
          value={cat}
          onPick={setCat}
          onClose={() => setPickerOpen(false)}
        />
      )}
    </div>
  );
};

Object.assign(window, { UploadItemScreen, CATEGORY_OPTIONS });
