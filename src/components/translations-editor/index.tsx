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
import { ArrowLeft, ArrowRight } from 'lucide-react'
import { useState, useEffect } from 'react'
import { TranslationEditorForm } from './translation-editor-form'

interface TranslationCreatorProps {
  translationKeyIds: string[]
}

export function TranslationEditor({
  translationKeyIds
}: TranslationCreatorProps) {
  const [open, setOpen] = useState(false)
  const [carouselApi, setCarouselApi] = useState<CarouselApi>()
  const [current, setCurrent] = useState(0)
  const [count, setCount] = useState(0)

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
      <SheetContent className="pb-0 overflow-y-auto">
        <SheetHeader>
          <SheetTitle>Edit Translations</SheetTitle>
          <SheetDescription>
            {current} of {count} translations
          </SheetDescription>
        </SheetHeader>

        <Carousel setApi={setCarouselApi}>
          <CarouselContent>
            {translationKeyIds.map((keyId) => (
              <CarouselItem key={keyId}>
                <TranslationEditorForm keyId={keyId} />
              </CarouselItem>
            ))}
          </CarouselContent>
        </Carousel>

        <SheetFooter className="flex-row justify-between sm:justify-between sm:space-x-0 sticky bottom-0 bg-background py-4">
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
          <Button>Save</Button>
        </SheetFooter>
      </SheetContent>
    </Sheet>
  )
}
