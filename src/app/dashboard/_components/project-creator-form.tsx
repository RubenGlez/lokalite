import * as React from 'react'
import { Button } from '@/components/ui/button'
import {
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle
} from '@/components/ui/dialog'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Textarea } from '@/components/ui/textarea'

interface ProjectCreatorFormProps {
  setShowNewProjectDialog: (value: boolean) => void
}

export default function ProjectCreatorForm({
  setShowNewProjectDialog
}: ProjectCreatorFormProps) {
  return (
    <DialogContent>
      <DialogHeader>
        <DialogTitle>Create project</DialogTitle>
        <DialogDescription>
          Add a new project to manage the translations.
        </DialogDescription>
      </DialogHeader>
      <div>
        <div className="space-y-4 py-2 pb-4">
          <div className="space-y-2">
            <Label htmlFor="name">Project name</Label>
            <Input id="name" placeholder="Acme Inc." />
          </div>
          <div className="space-y-2">
            <Label htmlFor="description">Description</Label>
            {/* <Textarea
              id="description"
              placeholder="Type your description here."
            /> */}
          </div>
        </div>
      </div>
      <DialogFooter>
        <Button
          variant="outline"
          onClick={() => setShowNewProjectDialog(false)}
        >
          Cancel
        </Button>
        <Button type="submit">Continue</Button>
      </DialogFooter>
    </DialogContent>
  )
}
