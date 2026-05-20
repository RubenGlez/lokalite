import { Button } from '~/components/ui/button'
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle
} from '~/components/ui/sheet'
import {
  Carousel,
  CarouselContent,
  CarouselItem,
  CarouselApi
} from '~/components/ui/carousel'
import { ArrowLeft, ArrowRight, Save } from 'lucide-react'
import { useState, useEffect, useMemo } from 'react'
import { TranslationsRowForm } from './translations-row-form'

import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { formSchema, FormValues } from './schema'
import { Form } from '../ui/form'
import { useTranslations } from '~/hooks/use-translations'

interface TranslationsCreatorProps {
  translationKeyIds: string[]
}

export function TranslationsEditor({
  translationKeyIds
}: TranslationsCreatorProps) {
  const [open, setOpen] = useState(false)
  const [carouselApi, setCarouselApi] = useState<CarouselApi>()
  const [current, setCurrent] = useState(0)
  const [count, setCount] = useState(0)

  const { data } = useTranslations()

  const defaultValues: FormValues = useMemo(() => {
    const keys = translationKeyIds.reduce((acc: FormValues['keys'], keyId) => {
      const current = data.find((translation) => translation.keyId === keyId)
      if (!current) return acc
      acc[keyId] = {
        key: current.keyValue,
        translations: current.translations
      }
      return acc
    }, {})
    return {
      keys
    }
  }, [data, translationKeyIds])

  const form = useForm<FormValues>({
    resolver: zodResolver(formSchema),
    defaultValues,
    values: defaultValues
  })

  const handleSubmit = (values: FormValues) => {
    // TODO
    console.log(values)
  }

  useEffect(() => {
    if (!carouselApi) {
      return
    }

    setCount(carouselApi.scrollSnapList().length)
    setCurrent(carouselApi.selectedScrollSnap() + 1)

    carouselApi.on('select', () => {
      setCurrent(carouselApi.selectedScrollSnap() + 1)
    })
  }, [carouselApi])

  useEffect(() => {
    if (translationKeyIds.length > 0) {
      setOpen(true)
    }
  }, [translationKeyIds])

  return (
    <Sheet open={open} onOpenChange={setOpen}>
      <SheetContent className="flex flex-col p-0 gap-0">
        <div className="flex flex-col flex-1 overflow-y-auto p-6">
          <SheetHeader>
            <SheetTitle>Edit Translations</SheetTitle>
            <SheetDescription>
              {current} of {count} translations
            </SheetDescription>
          </SheetHeader>

          <Form {...form}>
            <form onSubmit={form.handleSubmit(handleSubmit)} className="w-full">
              <Carousel setApi={setCarouselApi}>
                <CarouselContent>
                  {translationKeyIds.map((keyId) => (
                    <CarouselItem key={keyId}>
                      <TranslationsRowForm keyId={keyId} form={form} />
                    </CarouselItem>
                  ))}
                </CarouselContent>
              </Carousel>
            </form>
          </Form>
        </div>

        <SheetFooter className="flex-row sm:space-x-0 bg-background justify-between sm:justify-between p-6 border-t items-center">
          <div className="flex items-center gap-2">
            <Button
              size="icon"
              variant="secondary"
              disabled={!carouselApi?.canScrollPrev()}
              onClick={() => {
                carouselApi?.scrollPrev()
              }}
            >
              <ArrowLeft />
            </Button>
            <Button
              size="icon"
              variant="secondary"
              disabled={!carouselApi?.canScrollNext()}
              onClick={() => {
                carouselApi?.scrollNext()
              }}
            >
              <ArrowRight />
            </Button>
          </div>
          <div className="flex items-center gap-2">
            <Button onClick={form.handleSubmit(handleSubmit)}>
              <Save />
              Save
            </Button>
          </div>
        </SheetFooter>
      </SheetContent>
    </Sheet>
  )
}
