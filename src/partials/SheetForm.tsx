import Button from "@/components/Button";
import TextInput from "@/components/TextInput";
import { Sheet } from "@/lib/database.types";
import { FormEvent } from "react";

export type SheetFormData = Pick<Sheet, "name" | "description">;
interface SheetFormProps {
  handleSubmit: (form: SheetFormData) => void;
  handleCancel: () => void;
}

export default function SheetForm({
  handleSubmit,
  handleCancel,
}: SheetFormProps) {
  const onSubmit = (e: FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    const formData = new FormData(e.currentTarget);
    const formJson = Object.fromEntries(formData.entries());
    const form = {
      name: String(formJson.name),
      description: String(formJson.description),
    };

    handleSubmit(form);
  };

  return (
    <form onSubmit={onSubmit}>
      <TextInput
        name="name"
        label={"Nombre"}
        placeholder={"Nombre de la hoja"}
        className="mb-4"
      />
      <TextInput
        name="description"
        label={"Descripción"}
        placeholder={"Descripción de la hoja"}
        className="mb-4"
      />

      <div className="mt-8">
        <Button
          text={"Cancelar"}
          onClick={handleCancel}
          template="secondary"
          className="mr-8"
        />
        <Button type="submit" text={"Guardar"} />
      </div>
    </form>
  );
}
