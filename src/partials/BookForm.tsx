import Button from "@/components/Button";
import CheckGroup from "@/components/CheckGroup";
import ListBox from "@/components/ListBox";
import TextInput from "@/components/TextInput";
import { LANG_PREFIX } from "@/constants/global";
import { LANGUAGES } from "@/constants/languages";
import { useNavigation } from "@/hooks/useNavigation";
import { Book } from "@/lib/database.types";
import { CreateBookBody } from "@/lib/queries/createBook";
import { UpdateBookBody } from "@/lib/queries/updateBook";
import { FormEvent, useState } from "react";

interface BookFormProps {
  handleSubmit: (form: CreateBookBody | UpdateBookBody) => void;
  initialData?: Book;
}

export default function BookForm({ handleSubmit, initialData }: BookFormProps) {
  const { goTo } = useNavigation();
  const [defaultLang, setDefaultLang] = useState(
    initialData?.default_language ?? ""
  );
  const defaultLangOptions = LANGUAGES.map((lang) => ({
    value: lang.code,
    label: lang.name,
  }));
  const langOptions = LANGUAGES.filter(
    (lang) => lang.code !== defaultLang.replace(LANG_PREFIX, "")
  ).map((lang) => ({
    name: `${LANG_PREFIX}${lang.code}`,
    label: lang.name,
    defaultChecked: initialData?.languages?.includes(lang.code),
  }));
  const onSubmit = (e: FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    const formData = new FormData(e.currentTarget);
    const formJson = Object.fromEntries(formData.entries());
    const languages = Object.keys(formJson).reduce((acc: string[], curr) => {
      if (curr.startsWith(LANG_PREFIX) && formJson[curr] === "on") {
        return [...acc, curr.replace(LANG_PREFIX, "")];
      }
      return acc;
    }, []);
    const { name, description } = formJson;
    const form = {
      ...(initialData || {}),
      name: String(name),
      description: String(description),
      default_language: String(formJson["default_lang[value]"]),
      languages,
    };

    handleSubmit(form);
  };
  const handleCancel = () => {
    goTo("books");
  };
  const handleChange = (val: string | number) => {
    setDefaultLang(String(val));
  };

  return (
    <form onSubmit={onSubmit}>
      <TextInput
        name="name"
        label={"Nombre"}
        placeholder={"Nombre del libro"}
        className="mb-4"
        defaultValue={initialData?.name ?? ""}
      />
      <TextInput
        name="description"
        label={"Descripción"}
        placeholder={"Descripción del libro"}
        className="mb-4"
        defaultValue={initialData?.description ?? ""}
      />
      <ListBox
        name="default_lang"
        options={defaultLangOptions}
        label="Idioma por defecto"
        className="mb-4"
        handleChange={handleChange}
        defaultValue={initialData?.default_language ?? ""}
      />
      <CheckGroup
        label="Selecciona los idiomas"
        className="mb-4"
        columns={4}
        checkboxes={langOptions}
      />

      <div className="mt-8 flex gap-4">
        <Button text={"Cancelar"} onClick={handleCancel} template="secondary" />
        <Button type="submit" text={"Guardar"} />
      </div>
    </form>
  );
}
