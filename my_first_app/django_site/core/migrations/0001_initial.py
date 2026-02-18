from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    initial = True

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name='UserRoleProfile',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('role', models.CharField(choices=[('aww', 'AWW'), ('supervisor', 'Supervisor'), ('cdpo', 'CDPO'), ('district', 'District Officer'), ('state', 'State Officer')], max_length=20)),
                ('location_id', models.CharField(blank=True, default='', max_length=50)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('user', models.OneToOneField(on_delete=django.db.models.deletion.CASCADE, related_name='role_profile', to=settings.AUTH_USER_MODEL)),
            ],
        ),
    ]
