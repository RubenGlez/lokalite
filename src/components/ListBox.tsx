import { Fragment, useState } from "react";
import { Listbox, Transition } from "@headlessui/react";
import { CheckIcon, ChevronUpDownIcon } from "@heroicons/react/24/outline";
import { cls } from "@/utils";
import LabelInput from "./LabelInput";

export interface ListBoxOption {
  value: string | number;
  label: string;
}

interface ListBoxProps {
  label?: string;
  placeholder?: string;
  defaultValue?: ListBoxOption["value"];
  handleChange?: (value: ListBoxOption["value"]) => void;
  options: ListBoxOption[];
  className?: string;
  name?: string;
}

const EMPTY_STATE_TEXT = "No hay opciones disponibles";
const DEFAULT_PLACEHOLDER = "Elige una opción";

export default function ListBox({
  label,
  placeholder = DEFAULT_PLACEHOLDER,
  options = [],
  defaultValue,
  handleChange,
  className = "",
  name,
}: ListBoxProps) {
  const [selected, setSelected] = useState(defaultValue);
  const optionSelected = options.find((opt) => opt.value === selected);
  const onChange = (opt: any) => {
    setSelected(opt.value);
    handleChange?.(opt.value);
  };

  return (
    <div className={className}>
      <Listbox name={name} defaultValue={selected} onChange={onChange}>
        <div className="relative">
          <div className="flex flex-col">
            {label && (
              <div className="mb-1">
                <LabelInput text={label} />
              </div>
            )}
            <Listbox.Button className="relative px-3 py-2 border border-slate-700 bg-slate-900 focus:outline-none focus:border-slate-100 rounded-md text-left text-sm text-slate-100">
              <span className="block truncate text-slate-400">
                {!!optionSelected ? optionSelected.label : placeholder}
              </span>
              <span className="pointer-events-none absolute inset-y-0 right-2 flex items-center">
                <ChevronUpDownIcon
                  className="h-5 w-5 text-slate-400"
                  aria-hidden="true"
                />
              </span>
            </Listbox.Button>
          </div>
          <Transition
            as={Fragment}
            leave="transition ease-in duration-100"
            leaveFrom="opacity-100"
            leaveTo="opacity-0"
          >
            <Listbox.Options className="border border-slate-700 bg-slate-900 absolute mt-1 max-h-60 w-full overflow-auto rounded-md bg-slate-900 py-1 text-sm focus:outline-none focus:border-slate-100">
              {options.length > 0 ? (
                options.map((option) => {
                  const isSelected = option.value === optionSelected?.value;
                  return (
                    <Listbox.Option
                      key={option.value}
                      value={option}
                      className={({ active }) =>
                        `relative cursor-default select-none py-2 pl-11 pr-4 ${
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
                          <CheckIcon className="h-5 w-5" aria-hidden="true" />
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
    </div>
  );
}
