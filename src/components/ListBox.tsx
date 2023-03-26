import { Fragment } from "react";
import { Listbox, Transition } from "@headlessui/react";
import { CheckIcon, ChevronUpDownIcon } from "@heroicons/react/24/outline";
import { cls } from "@/utils";

export interface ListBoxOption {
  value: string;
  label: string;
}

interface ListBoxProps {
  options?: ListBoxOption[];
  value?: ListBoxOption["value"];
  handleChange: (value: ListBoxOption["value"]) => void;
  placeholder?: string;
}

const EMPTY_STATE_TEXT = "No hay opciones disponibles";

export default function ListBox({
  options = [],
  value,
  handleChange,
  placeholder = "Selecciona algo...",
}: ListBoxProps) {
  const optionSelected = options.find((opt) => opt.value === value);
  const onChange = (opt: any) => {
    handleChange(opt.value);
  };

  return (
    <Listbox value={value} onChange={onChange}>
      <div className="relative">
        <Listbox.Button className="border border-slate-700 relative w-full rounded-md bg-slate-900 py-1 pl-3 pr-10 text-left text-sm">
          <span className="block truncate text-slate-400">
            {!!optionSelected ? optionSelected.label : placeholder}
          </span>
          <span className="pointer-events-none absolute inset-y-0 right-0 flex items-center pr-2">
            <ChevronUpDownIcon
              className="h-4 w-4 text-slate-400"
              aria-hidden="true"
            />
          </span>
        </Listbox.Button>
        <Transition
          as={Fragment}
          leave="transition ease-in duration-100"
          leaveFrom="opacity-100"
          leaveTo="opacity-0"
        >
          <Listbox.Options className="border border-slate-700 absolute mt-1 max-h-60 w-full overflow-auto rounded-md bg-slate-900 py-1 text-sm">
            {options.length > 0 ? (
              options.map((option) => {
                const isSelected = option.value === optionSelected?.value;
                return (
                  <Listbox.Option
                    key={option.value}
                    value={option}
                    className={({ active }) =>
                      `relative cursor-default select-none py-2 pl-10 pr-4 ${
                        active
                          ? "bg-slate-800 text-slate-100"
                          : "text-slate-400"
                      }`
                    }
                  >
                    <span
                      className={cls({
                        "block truncate": true,
                        "text-slate-100": isSelected,
                      })}
                    >
                      {option.label}
                    </span>
                    {isSelected && (
                      <span className="absolute inset-y-0 left-0 flex items-center pl-3 text-slate-100">
                        <CheckIcon className="h-4 w-4" aria-hidden="true" />
                      </span>
                    )}
                  </Listbox.Option>
                );
              })
            ) : (
              <div className="relative cursor-default select-none py-2 pl-10 pr-4 text-slate-400">
                <span className="block truncate font-normal">
                  {EMPTY_STATE_TEXT}
                </span>
              </div>
            )}
          </Listbox.Options>
        </Transition>
      </div>
    </Listbox>
  );
}
