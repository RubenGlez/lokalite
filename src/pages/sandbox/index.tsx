import Button from "@/components/Button";
import Checkbox from "@/components/Checkbox";
import Layout from "@/components/Layout";
import ListBox from "@/components/ListBox";
import Text from "@/components/Text";
import TextInput from "@/components/TextInput";
const options = [
  {
    label: "Opción 1",
    value: "opt1",
  },
  {
    label: "Opción 2",
    value: "opt2",
  },
  {
    label: "Opción 3",
    value: "opt3",
  },
  {
    label: "Opción 4",
    value: "opt4",
  },
];

export default function SandboxPage() {
  return (
    <Layout>
      <div className="px-8 py-8">
        <div className="grid grid-cols-2 gap-8">
          <div>
            <Text className="mb-4" as="h3">
              Size Base
            </Text>
            <TextInput
              label="Text input"
              placeholder="im a text input"
              defaultValue="hello world"
              className="mb-4"
            />
            <ListBox
              label="List box"
              placeholder="im a listbox"
              defaultValue="opt1"
              options={options}
              className="mb-4"
            />
            <Checkbox label="Checkbox" className="mb-4" />
            <Button
              text={"Botón"}
              type="secondary"
              onClick={() => {}}
              className="mr-4"
            />
            <Button text={"Botón"} type="primary" onClick={() => {}} />
          </div>
          <div>
            <Text className="mb-4" as="h3">
              Size SM
            </Text>
            <TextInput
              label="Text input"
              placeholder="im a text input"
              defaultValue="hello world"
              className="mb-4"
            />
            <ListBox
              label="List box"
              placeholder="im a listbox"
              defaultValue="opt1"
              options={options}
              className="mb-4"
            />
            <Checkbox label="Checkbox" className="mb-4" />
            <Button
              text={"Botón"}
              type="secondary"
              onClick={() => {}}
              className="mr-4"
            />
            <Button text={"Botón"} type="primary" onClick={() => {}} />
          </div>
        </div>
      </div>
    </Layout>
  );
}
