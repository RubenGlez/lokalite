'use client'

import { Button } from '~/components/ui/button'

import { availableLanguages } from '~/lib/languages'
import {
  Card,
  CardHeader,
  CardTitle,
  CardContent,
  CardDescription
} from './ui/card'
import { Language } from '~/server/db/schema'

import { api } from '~/trpc/react'
import { Switch } from './ui/switch'
import { Trash2 } from 'lucide-react'

interface LanguageListProps {
  languages: Language[]
  projectId: string
}

export function LanguagesList({ languages, projectId }: LanguageListProps) {
  const utils = api.useUtils()

  const createLanguage = api.languages.create.useMutation({
    onSuccess: () => {
      utils.languages.invalidate()
    }
  })

  const deleteLanguage = api.languages.delete.useMutation({
    onSuccess: () => {
      utils.languages.invalidate()
    }
  })

  const setAsSource = api.languages.setAsSource.useMutation({
    onSuccess: () => {
      utils.languages.invalidate()
    }
  })

  const languagesToShow = availableLanguages.filter(
    (language) => !languages.some((l) => l.code === language.code)
  )

  const isLoading =
    createLanguage.isPending ||
    deleteLanguage.isPending ||
    setAsSource.isPending

  return (
    <Card>
      <CardHeader>
        <CardTitle>Languages configuration</CardTitle>
        <CardDescription>
          Select the languages you want to use in your project and configure the
          source language.
        </CardDescription>
      </CardHeader>
      <CardContent>
        <div className="flex flex-col gap-8">
          <div className="flex flex-col gap-2">
            <p className="text-sm text-muted-foreground">
              Used in your project
            </p>
            <div className="grid grid-cols-3 gap-2">
              {languages.map((language) => {
                return (
                  <div
                    key={language.code}
                    className="flex flex-row items-center rounded-md border gap-16 px-4 py-2 justify-between"
                  >
                    <div className="flex flex-col min-w-0">
                      <span className="text-md truncate">{language.name}</span>
                      <span className="text-sm text-muted-foreground">
                        {language.code}
                      </span>
                    </div>
                    <div className="flex flex-row items-center gap-4">
                      <Button
                        disabled={isLoading}
                        variant="outline"
                        size="icon"
                        onClick={() => {
                          deleteLanguage.mutate({
                            id: language.id
                          })
                        }}
                      >
                        <Trash2 />
                      </Button>
                      <Switch
                        disabled={isLoading}
                        id="airplane-mode"
                        checked={language.isSource}
                        onCheckedChange={() => {
                          setAsSource.mutate({
                            id: language.id,
                            projectId
                          })
                        }}
                      />
                    </div>
                  </div>
                )
              })}
            </div>
          </div>

          <div className="flex flex-col gap-2">
            <p className="text-sm text-muted-foreground">Available languages</p>
            <div className="flex flex-row flex-wrap gap-2">
              {languagesToShow.map((language) => {
                return (
                  <Button
                    key={language.code}
                    disabled={isLoading}
                    variant="outline"
                    onClick={() => {
                      createLanguage.mutate({
                        projectId,
                        code: language.code,
                        name: language.name,
                        isSource: languages.length === 0
                      })
                    }}
                  >
                    <span>{language.name}</span>
                    <span className="text-muted-foreground">
                      {language.code}
                    </span>
                  </Button>
                )
              })}
            </div>
          </div>
        </div>
      </CardContent>
    </Card>
  )
}
