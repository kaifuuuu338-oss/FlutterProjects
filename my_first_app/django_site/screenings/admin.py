from django.contrib import admin
from .models import Child, Question, Screening, Response, DomainScore

admin.site.register(Child)
admin.site.register(Question)
admin.site.register(Screening)
admin.site.register(Response)
admin.site.register(DomainScore)
