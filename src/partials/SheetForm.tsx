import Button from "@/components/Button";
import TextInput from "@/components/TextInput";
import { useNavigation } from "@/hooks/useNavigation";
import { Sheet } from "@/lib/database.types";
import { FormEvent } from "react";

export type SheetFormData = Pick<Sheet, "name" | "description">;
interface SheetFormProps {
  handleSubmit: (form: SheetFormData) => void;
  initialData?: Sheet;
}

export default function SheetForm({
  handleSubmit,
  initialData,
}: SheetFormProps) {
  const { goTo } = useNavigation();
  const onSubmit = (e: FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    const formData = new FormData(e.currentTarget);
    const formJson = Object.fromEntries(formData.entries());
    const form = {
      ...(initialData || {}),
      name: String(formJson.name),
      description: String(formJson.description),
    };

    handleSubmit(form);
  };
  const handleCancel = () => {
    goTo("sheets", { bookId: initialData?.book_id });
  };

  return (
    <form onSubmit={onSubmit}>
      <TextInput
        name="name"
        label={"Nombre"}
        placeholder={"Nombre de la hoja"}
        className="mb-4"
        defaultValue={initialData?.name ?? ""}
      />
      <TextInput
        name="description"
        label={"Descripción"}
        placeholder={"Descripción de la hoja"}
        className="mb-4"
        defaultValue={initialData?.description ?? ""}
      />

      <div className="mt-8 flex gap-4">
        <Button text={"Cancelar"} onClick={handleCancel} template="secondary" />
        <Button type="submit" text={"Guardar"} />
      </div>
    </form>
  );
}
