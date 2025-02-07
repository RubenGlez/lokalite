import { Button } from '~/components/ui/button'
import {
  Sheet,
  SheetClose,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
  SheetTrigger
} from '~/components/ui/sheet'
import { Textarea } from './ui/textarea'
import { Input } from './ui/input'
import { api } from '~/trpc/react'
import { useSelectedProject } from '~/hooks/use-selected-project'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import {
  Form,
  FormControl,
  FormField,
  FormItem,
  FormLabel,
  FormMessage
} from './ui/form'
import { z } from 'zod'
import { useSelectedPage } from '~/hooks/use-selected-page'
import { useRouter } from 'next/navigation'
import { ReactNode, useMemo } from 'react'

interface TranslationCreatorProps {
  children: ReactNode
  onCreated: () => void
}

interface FormValues {
  key: string
  translations: Record<string, string>
}

const formSchema = z.object({
  key: z
    .string()
    .min(1)
    .regex(/^[a-zA-Z0-9_]+$/, {
      message: 'Key can only contain letters, numbers, and underscores'
    }),
  translations: z.record(z.string(), z.string().optional())
})

export function TranslationCreator({
  children,
  onCreated
}: TranslationCreatorProps) {
  const utils = api.useUtils()
  const router = useRouter()
  const selectedProject = useSelectedProject()
  const selectedPage = useSelectedPage()
  const { data: languages } = api.languages.getByProject.useQuery(
    {
      projectId: selectedProject?.id ?? ''
    },
    {
      enabled: !!selectedProject?.id
    }
  )

  const sourceLanguage = useMemo(
    () => languages?.find((language) => language.isSource),
    [languages]
  )

  const createFullTranslation =
    api.translations.createFullTranslation.useMutation({
      onSuccess: async () => {
        form.reset()
        await utils.translationKeys.invalidate()
        await utils.translations.invalidate()
        router.refresh()
        onCreated()
      },
      onError: (error) => {
        if (error.message.includes('unique')) {
          form.setError('key', {
            message: 'Translation key already exists'
          })
        }
      }
    })

  const form = useForm<FormValues>({
    resolver: zodResolver(formSchema),
    defaultValues: {
      key: '',
      translations: {}
    }
  })

  const handleSubmit = (values: FormValues) => {
    if (!selectedProject?.id || !selectedPage?.id) {
      return
    }

    createFullTranslation.mutate({
      projectId: selectedProject.id,
      pageId: selectedPage.id,
      key: values.key,
      translations: values.translations
    })
  }

  return (
    <Sheet>
      <SheetTrigger asChild>{children}</SheetTrigger>
      <SheetContent>
        <SheetHeader>
          <SheetTitle>Create Translation</SheetTitle>
          <SheetDescription>
            Create a new translation for the current page.
          </SheetDescription>
        </SheetHeader>

        <Form {...form}>
          <form
            onSubmit={form.handleSubmit(handleSubmit)}
            className="flex flex-col gap-6 py-8"
          >
            <FormField
              control={form.control}
              name="key"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Key</FormLabel>
                  <FormControl>
                    <Input placeholder="The translation key" {...field} />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />

            {languages?.map((language) => (
              <FormField
                key={language.id}
                control={form.control}
                name={`translations.${language.code}`}
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>
                      {language.code === sourceLanguage?.code
                        ? `${language.name} (Default)`
                        : language.name}
                    </FormLabel>
                    <FormControl>
                      <Textarea
                        placeholder="The translation value"
                        {...field}
                      />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />
            ))}
          </form>
        </Form>

        <SheetFooter className="flex justify-between mt-6">
          <SheetClose asChild>
            <Button variant="secondary">Cancel</Button>
          </SheetClose>
          <Button
            disabled={createFullTranslation.isPending}
            onClick={form.handleSubmit(handleSubmit)}
          >
            Save
          </Button>
        </SheetFooter>
      </SheetContent>
    </Sheet>
  )
}
