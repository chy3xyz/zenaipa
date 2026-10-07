import { createSignal, For, Show, type JSX } from 'solid-js';

export type SearchFieldValue = string | number;
export type SearchValues = Record<string, SearchFieldValue | undefined>;

export type SearchField =
  | { key: string; label: string; type: 'text' | 'number'; placeholder?: string }
  | { key: string; label: string; type: 'select'; placeholder?: string; options: { value: string; label: string }[] };

interface SearchBarProps {
  fields: SearchField[];
  values?: SearchValues;
  onSearch: (values: SearchValues) => void;
  onReset?: () => void;
}

const widthClass: Record<SearchField['type'], string> = {
  text: 'w-44',
  number: 'w-28',
  select: 'w-36',
};

/**
 * 声明式筛选栏（草稿式）：输入只落在本地 draft，点「查询」才上报 onSearch；
 * 「重置」清空草稿并以空值触发一次 onSearch。
 */
export function SearchBar(props: SearchBarProps) {
  const [draft, setDraft] = createSignal<SearchValues>({ ...(props.values ?? {}) });

  const set = (key: string, value: SearchFieldValue | undefined) => {
    setDraft((d) => ({ ...d, [key]: value }));
  };

  const onSubmit = (e: Event) => {
    e.preventDefault();
    props.onSearch({ ...draft() });
  };

  const onReset = () => {
    setDraft({});
    props.onReset?.();
    props.onSearch({});
  };

  return (
    <form class="flex flex-wrap items-end gap-3" onSubmit={onSubmit}>
      <For each={props.fields}>
        {(f) => (
          <label class="form-control">
            <span class="mb-1 text-xs text-base-content/60">{f.label}</span>
            <Show
              when={f.type === 'select'}
              fallback={
                <input
                  type={f.type === 'number' ? 'number' : 'text'}
                  class={`input input-bordered input-sm ${widthClass[f.type]}`}
                  placeholder={f.placeholder ?? ''}
                  value={(draft()[f.key] as SearchFieldValue | undefined) ?? ''}
                  onInput={(e) => set(f.key, e.currentTarget.value === '' ? undefined : e.currentTarget.value)}
                />
              }
            >
              <select
                class={`select select-bordered select-sm ${widthClass.select}`}
                value={(draft()[f.key] as SearchFieldValue | undefined) ?? ''}
                onChange={(e) => set(f.key, e.currentTarget.value === '' ? undefined : e.currentTarget.value)}
              >
                <option value="">{(f as { placeholder?: string }).placeholder ?? '全部'}</option>
                <For each={(f as { options: { value: string; label: string }[] }).options}>
                  {(o) => <option value={o.value}>{o.label}</option>}
                </For>
              </select>
            </Show>
          </label>
        )}
      </For>
      <div class="flex gap-2">
        <button type="submit" class="btn btn-primary btn-sm">
          查询
        </button>
        <button type="button" class="btn btn-ghost btn-sm" onClick={onReset}>
          重置
        </button>
      </div>
    </form>
  );
}
