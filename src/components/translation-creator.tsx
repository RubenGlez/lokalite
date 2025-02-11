import { Button } from '~/components/ui/button'
import {
  Sheet,
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
import { ReactNode, useCallback, useMemo, useState } from 'react'
import { Languages, LoaderIcon, Save } from 'lucide-react'

interface TranslationCreatorProps {
  children: ReactNode
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

export function TranslationCreator({ children }: TranslationCreatorProps) {
  const [open, setOpen] = useState(false)
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

  const translateRow = api.translations.translateRow.useMutation({
    onSuccess(data) {
      form.reset({
        translations: data.reduce((acc, curr) => {
          return {
            ...acc,
            [curr.languageCode]: curr.value
          }
        }, {})
      })
    }
  })

  const createFullTranslation =
    api.translations.createFullTranslation.useMutation({
      onSuccess: () => {
        form.reset({
          key: '',
          translations: languages?.reduce(
            (acc, language) => ({
              ...acc,
              [language.code]: ''
            }),
            {}
          )
        })
        utils.translationKeys.invalidate()
        utils.translations.invalidate()
        router.refresh()
        setOpen(false)
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

  const sourceLanguageValue = sourceLanguage?.code
    ? form.getValues(`translations.${sourceLanguage.code}`)
    : ''

  const handleTranslate = useCallback(() => {
    if (!selectedProject?.id || !selectedPage?.id || !sourceLanguage?.code) {
      return
    }

    translateRow.mutate({
      projectId: selectedProject.id,
      pageId: selectedPage.id,
      sourceLanguageCode: sourceLanguage.code,
      itemsToTranslate: Object.entries(form.getValues('translations')).map(
        ([langCode], index) => ({
          keyId: `fake_key_${index}`,
          targetLanguageCode: langCode,
          text: sourceLanguageValue
        })
      )
    })
  }, [
    form,
    selectedPage?.id,
    selectedProject?.id,
    sourceLanguage?.code,
    sourceLanguageValue,
    translateRow
  ])

  return (
    <Sheet open={open} onOpenChange={setOpen}>
      <SheetTrigger asChild>{children}</SheetTrigger>
      <SheetContent className="flex flex-col p-0 gap-0">
        <div className="flex flex-col flex-1 overflow-y-auto p-6">
          <SheetHeader>
            <SheetTitle>Create translation</SheetTitle>
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

              {languages
                ?.sort((a, b) => (a.isSource ? -1 : b.isSource ? 1 : 0))
                .map((language) => (
                  <FormField
                    key={language.id}
                    control={form.control}
                    name={`translations.${language.code}`}
                    render={({ field }) => (
                      <FormItem>
                        <FormLabel>
                          {language.code === sourceLanguage?.code
                            ? `${language.name} (Source)`
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
        </div>

        <SheetFooter className="flex-row sm:space-x-0 bg-background justify-between sm:justify-between p-6 border-t items-center">
          <Button
            variant="secondary"
            disabled={translateRow.isPending || !sourceLanguageValue}
            onClick={handleTranslate}
          >
            {translateRow.isPending ? (
              <>
                <LoaderIcon className="animate-spin" />
                Translating...
              </>
            ) : (
              <>
                <Languages />
                Translate
              </>
            )}
          </Button>
          <Button
            disabled={createFullTranslation.isPending}
            onClick={form.handleSubmit(handleSubmit)}
          >
            {createFullTranslation.isPending ? (
              <>
                <LoaderIcon className="animate-spin" />
                Saving...
              </>
            ) : (
              <>
                <Save />
                Save
              </>
            )}
          </Button>
        </SheetFooter>
      </SheetContent>
    </Sheet>
  )
}
